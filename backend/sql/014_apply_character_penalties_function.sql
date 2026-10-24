-- p_hp_lossには、バックエンド側の設定値（仮設定20）を渡す。
create or replace function public.apply_character_penalties(
  p_user_id uuid,
  p_hp_loss integer
) returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  target_character public.characters%rowtype;
  today date := (now() at time zone 'Asia/Tokyo')::date;
  target_date date;
  processed boolean := false;
begin
  if p_hp_loss is null or p_hp_loss <= 0 then
    raise exception 'p_hp_loss must be a positive integer' using errcode = '22023';
  end if;

  -- 同じユーザーの処理を直列にし、二重にHPを減らすことを防ぐ。
  perform 1 from public.users where id = p_user_id for update;
  if not found then
    return;
  end if;

  select c.* into target_character
  from public.characters as c
  where c.user_id = p_user_id
  order by c.generation desc
  limit 1
  for update;

  if not found then
    return;
  end if;
  if target_character.status <> 'alive' then
    return;
  end if;

  for target_date in
    select d.penalty_date
    from public.get_pending_penalty_dates(
      (target_character.created_at at time zone 'Asia/Tokyo')::date,
      target_character.last_penalty_applied_date,
      target_character.second_evolution_date,
      today
    ) as d
    order by d.penalty_date
  loop
    if not public.has_character_deed_on_date(p_user_id, target_character.id, target_date) then
      target_character.hp := greatest(0, target_character.hp - p_hp_loss);
    end if;

    -- 投稿があった日も確認済みにして、次回の処理から除く。
    target_character.last_penalty_applied_date := target_date;
    processed := true;

    if target_character.hp = 0 then
      target_character.status := 'dead';
      -- HPが0になった対象日の末尾を記録し、後日アクセスした日と区別する。
      target_character.died_at :=
        ((target_date + 1)::timestamp at time zone 'Asia/Tokyo') - interval '1 millisecond';
      target_character.ended_at := target_character.died_at;
      target_character.end_reason := 'death';
      exit;
    end if;
  end loop;

  if processed then
    -- HP・死亡情報・最終確認日を、同じトランザクションで保存する。
    update public.characters
    set hp = target_character.hp,
        status = target_character.status,
        died_at = target_character.died_at,
        ended_at = target_character.ended_at,
        end_reason = target_character.end_reason,
        last_penalty_applied_date = target_character.last_penalty_applied_date
    where id = target_character.id;
  end if;
end;
$$;

revoke all on function public.apply_character_penalties(uuid, integer)
  from public, anon, authenticated;

grant execute on function public.apply_character_penalties(uuid, integer)
  to service_role;
