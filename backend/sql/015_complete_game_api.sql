begin;

-- 仮設定はここに集約。XP上限後の属性ポイントは付与しない。
create table if not exists public.game_config (
  singleton boolean primary key default true check (singleton),
  daily_xp_limit integer not null check (daily_xp_limit > 0),
  xp_per_deed integer not null check (xp_per_deed > 0),
  hp_recovery integer not null check (hp_recovery > 0),
  hp_loss_per_day integer not null check (hp_loss_per_day > 0),
  first_evolution_xp integer not null check (first_evolution_xp > 0),
  second_evolution_xp integer not null,
  level_xp_step integer not null check (level_xp_step > 0),
  check (second_evolution_xp > first_evolution_xp),
  check (xp_per_deed <= first_evolution_xp),
  check (second_evolution_xp - first_evolution_xp >= xp_per_deed)
);
insert into public.game_config values (true, 50, 10, 20, 20, 100, 300, 50)
on conflict (singleton) do nothing;
alter table public.game_config enable row level security;

alter table public.characters add column if not exists second_evolution_points jsonb not null default
  '{"kindness":0,"environment":0,"gratitude":0,"courage":0,"cooperation":0,"honesty":0,"self_care":0}'::jsonb;

create table if not exists public.deed_requests (
  user_id uuid not null references public.users(id) on delete cascade,
  request_id uuid not null,
  content text not null,
  character_id uuid not null,
  status text not null check (status in ('processing', 'retryable', 'completed')),
  lease_token uuid not null,
  lease_until timestamptz,
  http_status integer,
  response_body jsonb,
  created_at timestamptz not null default now(),
  primary key (user_id, request_id),
  foreign key (character_id, user_id) references public.characters(id, user_id) on delete cascade,
  check (status <> 'completed' or (http_status is not null and response_body is not null))
);
alter table public.deed_requests enable row level security;

-- 全てのゲーム更新は最初にユーザーをロックし、同じユーザーの変更を直列化する。
create or replace function public.settle_character_state(p_user_id uuid)
returns void language plpgsql security invoker set search_path = public as $$
declare c public.characters%rowtype; loss integer; today date := (now() at time zone 'Asia/Tokyo')::date;
begin
  perform 1 from public.users where id = p_user_id for update;
  if not found then return; end if;
  select hp_loss_per_day into strict loss from public.game_config where singleton;
  perform public.apply_character_penalties(p_user_id, loss);
  select * into c from public.characters where user_id = p_user_id order by generation desc limit 1 for update;
  if found and c.status = 'alive' and c.second_evolution_date < today then
    update public.characters set status = 'retired', end_reason = 'second_evolution',
      ended_at = ((c.second_evolution_date + 1)::timestamp at time zone 'Asia/Tokyo')
    where id = c.id;
  end if;
end;
$$;

create or replace function public.character_api(p_character_id uuid)
returns jsonb language sql stable security invoker set search_path = public as $$
  select jsonb_build_object(
    'id', c.id, 'generation', c.generation, 'imageId', c.image_id,
    'hp', c.hp, 'maxHp', c.max_hp, 'totalXp', c.total_xp, 'level', c.level,
    'evolutionStage', c.evolution_stage, 'firstEvolutionCategory', c.first_evolution_category,
    'secondEvolutionCategory', c.second_evolution_category, 'secondEvolutionDate', c.second_evolution_date,
    'categoryPoints', (c.category_points - 'self_care') || jsonb_build_object('selfCare', c.category_points->'self_care'),
    'status', c.status, 'createdAt', c.created_at, 'diedAt', c.died_at, 'endedAt', c.ended_at,
    'endReason', c.end_reason,
    'lifespanDays', (case when c.status = 'dead' then (c.died_at at time zone 'Asia/Tokyo')::date
      when c.second_evolution_date is not null then least(c.second_evolution_date, (now() at time zone 'Asia/Tokyo')::date)
      else (now() at time zone 'Asia/Tokyo')::date end) - (c.created_at at time zone 'Asia/Tokyo')::date + 1,
    'deedCount', (select count(*) from public.deeds d where d.character_id = c.id and d.user_id = c.user_id)
  ) from public.characters c where c.id = p_character_id;
$$;

create or replace function public.create_next_character(p_user_id uuid, p_character_id uuid)
returns jsonb language plpgsql security invoker set search_path = public as $$
declare c public.characters%rowtype; available_on date; today date := (now() at time zone 'Asia/Tokyo')::date;
begin
  perform 1 from public.users where id = p_user_id for update;
  if not found then return jsonb_build_object('errorCode','USER_NOT_FOUND'); end if;
  perform public.settle_character_state(p_user_id);
  select * into c from public.characters where user_id = p_user_id order by generation desc limit 1 for update;
  if not found then return jsonb_build_object('errorCode','CHARACTER_NOT_FOUND'); end if;
  if c.status = 'alive' then return jsonb_build_object('errorCode','ACTIVE_CHARACTER_EXISTS'); end if;
  available_on := case when c.status = 'dead' then (c.died_at at time zone 'Asia/Tokyo')::date + 1
    else c.second_evolution_date + 1 end;
  if available_on is null or today < available_on then
    return jsonb_build_object('errorCode','GENERATION_NOT_AVAILABLE');
  end if;
  insert into public.characters (id,user_id,generation,image_id,last_penalty_applied_date)
    values (p_character_id,p_user_id,c.generation+1,'base_01',today);
  return jsonb_build_object('currentCharacter',public.character_api(p_character_id));
end;
$$;

-- 有効な投稿だけに報酬を付与するため、AI処理前は要求の予約だけを保存する。
create or replace function public.begin_deed_request(
  p_user_id uuid, p_request_id uuid, p_content text, p_lease_token uuid
) returns jsonb language plpgsql security invoker set search_path = public as $$
declare r public.deed_requests%rowtype; c public.characters%rowtype; player_name text; reset_invalid boolean := false;
begin
  select display_name into player_name from public.users where id = p_user_id for update;
  if not found then return jsonb_build_object('errorCode','USER_NOT_FOUND'); end if;
  select * into r from public.deed_requests where user_id = p_user_id and request_id = p_request_id for update;
  if found then
    -- 善行ではないという判定は、同じIDのまま内容を上書きして再判定できる。
    reset_invalid := r.status = 'completed' and r.http_status = 422;
    if not reset_invalid then
      if r.content <> p_content then return jsonb_build_object('errorCode','IDEMPOTENCY_CONFLICT'); end if;
      if r.status = 'completed' then
        return jsonb_build_object('kind','replay','httpStatus',r.http_status,'body',r.response_body);
      end if;
      if r.status = 'processing' and r.lease_until > clock_timestamp() then
        return jsonb_build_object('errorCode','REQUEST_IN_PROGRESS');
      end if;
    end if;
  end if;
  perform public.settle_character_state(p_user_id);
  select * into c from public.characters where user_id = p_user_id order by generation desc limit 1 for update;
  if not found then return jsonb_build_object('errorCode','CHARACTER_NOT_FOUND'); end if;
  if c.status <> 'alive' then return jsonb_build_object('errorCode','CHARACTER_NOT_ACTIVE'); end if;
  if r.user_id is not null and not reset_invalid and r.character_id <> c.id then
    return jsonb_build_object('errorCode','CHARACTER_NOT_ACTIVE');
  end if;
  insert into public.deed_requests(user_id,request_id,content,character_id,status,lease_token,lease_until)
    values(p_user_id,p_request_id,p_content,c.id,'processing',p_lease_token,clock_timestamp()+interval '90 seconds')
  on conflict(user_id,request_id) do update set content=excluded.content,character_id=excluded.character_id,
    status='processing',lease_token=excluded.lease_token,lease_until=excluded.lease_until,http_status=null,response_body=null;
  return jsonb_build_object('kind','ready','characterId',c.id,'displayName',player_name);
end;
$$;

create or replace function public.choose_evolution_category(p_character_id uuid, p_points jsonb)
returns text language sql stable security invoker set search_path = public as $$
  select points.key from jsonb_each_text(p_points) points
  left join lateral (select max(created_at) as last_post from public.deeds
    where character_id=p_character_id and category=points.key) recent on true
  order by points.value::integer desc, recent.last_post desc nulls last,
    array_position(array['kindness','environment','gratitude','courage','cooperation','honesty','self_care'],points.key)
  limit 1;
$$;

create or replace function public.finish_deed_request(
  p_user_id uuid, p_request_id uuid, p_lease_token uuid,
  p_valid boolean, p_category text, p_praise text
) returns jsonb language plpgsql security invoker set search_path = public as $$
declare
  r public.deed_requests%rowtype; c public.characters%rowtype; cfg public.game_config%rowtype;
  result jsonb; deed_id uuid := gen_random_uuid(); stamp timestamptz := now();
  today date := (now() at time zone 'Asia/Tokyo')::date;
  already_xp bigint; earned integer; points integer; healed integer; previous_stage integer; response_status integer;
begin
  perform 1 from public.users where id=p_user_id for update;
  if not found then return jsonb_build_object('errorCode','USER_NOT_FOUND'); end if;
  select * into r from public.deed_requests where user_id=p_user_id and request_id=p_request_id for update;
  if not found then return jsonb_build_object('errorCode','REQUEST_NOT_FOUND'); end if;
  if r.status='completed' then return jsonb_build_object('httpStatus',r.http_status,'body',r.response_body); end if;
  if r.status <> 'processing' or r.lease_token <> p_lease_token then
    return jsonb_build_object('errorCode','REQUEST_IN_PROGRESS');
  end if;
  if p_valid is null then raise exception 'AI validity is required' using errcode='22023'; end if;
  if not p_valid then
    response_status := 422;
    result := jsonb_build_object('error',jsonb_build_object('code','DEED_NOT_VALID',
      'message','善行として確認できませんでした。内容を編集して再判定できます。','requestId',p_lease_token));
  else
    if p_category is null or p_category not in ('kindness','environment','gratitude','courage','cooperation','honesty','self_care')
       or p_praise is null or length(btrim(p_praise))=0 or length(p_praise)>500 then
      raise exception 'Invalid AI result' using errcode='22023';
    end if;
    perform public.settle_character_state(p_user_id);
    select * into c from public.characters where user_id=p_user_id order by generation desc limit 1 for update;
    if not found or c.id<>r.character_id or c.status<>'alive' then
      response_status := 409;
      result := jsonb_build_object('error',jsonb_build_object('code','CHARACTER_NOT_ACTIVE',
        'message','このキャラクターには投稿できません。','requestId',p_lease_token));
    else
      select * into strict cfg from public.game_config where singleton;
      select coalesce(sum(earned_xp),0) into already_xp from public.deeds
        where user_id=p_user_id and created_at >= (today::timestamp at time zone 'Asia/Tokyo')
        and created_at < ((today+1)::timestamp at time zone 'Asia/Tokyo');
      earned := least(cfg.xp_per_deed,greatest(0,cfg.daily_xp_limit-already_xp))::integer;
      -- XP上限後は属性ポイントも0。HP回復と褒め言葉は継続する。
      points := case when earned>0 then 1 else 0 end;
      healed := least(cfg.hp_recovery,c.max_hp-c.hp);
      previous_stage := c.evolution_stage;
      c.hp := c.hp+healed; c.total_xp := c.total_xp+earned;
      c.level := 1+c.total_xp/cfg.level_xp_step;
      if points>0 then
        c.category_points := jsonb_set(c.category_points,array[p_category],to_jsonb((c.category_points->>p_category)::integer+points));
        if previous_stage=1 then
          c.second_evolution_points := jsonb_set(c.second_evolution_points,array[p_category],
            to_jsonb((c.second_evolution_points->>p_category)::integer+points));
        end if;
      end if;
      insert into public.deeds(id,user_id,character_id,request_id,content,category,praise,earned_xp,earned_category_points,recovered_hp,created_at)
        values(deed_id,p_user_id,c.id,p_request_id,r.content,p_category,p_praise,earned,points,healed,stamp);
      if c.evolution_stage=0 and c.total_xp>=cfg.first_evolution_xp then
        c.first_evolution_category := public.choose_evolution_category(c.id,c.category_points);
        c.evolution_stage := 1; c.image_id := 'stage1_'||c.first_evolution_category;
      end if;
      if c.evolution_stage=1 and c.total_xp>=cfg.second_evolution_xp then
        c.second_evolution_category := public.choose_evolution_category(c.id,c.second_evolution_points);
        c.evolution_stage := 2; c.second_evolution_date := today;
        c.image_id := 'stage2_'||c.first_evolution_category||'_'||c.second_evolution_category;
      end if;
      update public.characters set hp=c.hp,total_xp=c.total_xp,level=c.level,evolution_stage=c.evolution_stage,
        category_points=c.category_points,second_evolution_points=c.second_evolution_points,
        first_evolution_category=c.first_evolution_category,second_evolution_category=c.second_evolution_category,
        second_evolution_date=c.second_evolution_date,image_id=c.image_id where id=c.id;
      result := jsonb_build_object('deed',jsonb_build_object('id',deed_id,'characterId',c.id,'content',r.content,
        'category',p_category,'praise',p_praise,'earnedXp',earned,'earnedCategoryPoints',points,
        'recoveredHp',healed,'createdAt',stamp),'xpLimitReached',already_xp+earned>=cfg.daily_xp_limit,
        'evolution',jsonb_build_object('changed',previous_stage<>c.evolution_stage,'previousStage',previous_stage,'currentStage',c.evolution_stage),
        'currentCharacter',public.character_api(c.id));
      response_status := 201;
    end if;
  end if;
  update public.deed_requests set status='completed',http_status=response_status,response_body=result,lease_until=null
    where user_id=p_user_id and request_id=p_request_id;
  return jsonb_build_object('httpStatus',response_status,'body',result);
end;
$$;

create or replace function public.release_deed_request(p_user_id uuid,p_request_id uuid,p_lease_token uuid)
returns void language sql security invoker set search_path=public as $$
  update public.deed_requests set status='retryable',lease_until=null
    where user_id=p_user_id and request_id=p_request_id and lease_token=p_lease_token and status='processing';
$$;

create or replace function public.get_character_history(p_user_id uuid,p_limit integer,p_offset integer)
returns jsonb language plpgsql security invoker set search_path=public as $$
declare total bigint; items jsonb;
begin
  if p_limit<1 or p_limit>50 or p_offset<0 or p_limit is null or p_offset is null then
    raise exception 'Invalid pagination' using errcode='22023';
  end if;
  perform public.settle_character_state(p_user_id);
  select count(*) into total from public.characters where user_id=p_user_id;
  select coalesce(jsonb_agg(public.character_api(page.id) order by page.generation desc),'[]'::jsonb) into items
    from (select id,generation from public.characters where user_id=p_user_id order by generation desc limit p_limit offset p_offset) page;
  return jsonb_build_object('items',items,'totalCount',total,'limit',p_limit,'offset',p_offset,'hasMore',p_offset+jsonb_array_length(items)<total);
end;
$$;

create or replace function public.delete_guest_account(p_user_id uuid)
returns void language plpgsql security invoker set search_path=public as $$
begin
  perform 1 from public.users where id=p_user_id for update;
  delete from public.users where id=p_user_id;
end;
$$;

-- Flutterからの直接参照・更新を禁止。Node.jsのservice_roleのみが操作する。
alter table public.users enable row level security;
alter table public.characters enable row level security;
alter table public.guest_sessions enable row level security;
alter table public.guest_registration_requests enable row level security;
grant select, insert, update, delete on public.game_config, public.deed_requests to service_role;

revoke all on function public.settle_character_state(uuid),public.character_api(uuid),
  public.create_next_character(uuid,uuid),public.begin_deed_request(uuid,uuid,text,uuid),
  public.choose_evolution_category(uuid,jsonb),public.finish_deed_request(uuid,uuid,uuid,boolean,text,text),
  public.release_deed_request(uuid,uuid,uuid),public.get_character_history(uuid,integer,integer),
  public.delete_guest_account(uuid) from public,anon,authenticated;
grant execute on function public.settle_character_state(uuid),public.character_api(uuid),
  public.create_next_character(uuid,uuid),public.begin_deed_request(uuid,uuid,text,uuid),
  public.choose_evolution_category(uuid,jsonb),public.finish_deed_request(uuid,uuid,uuid,boolean,text,text),
  public.release_deed_request(uuid,uuid,uuid),public.get_character_history(uuid,integer,integer),
  public.delete_guest_account(uuid) to service_role;

commit;
