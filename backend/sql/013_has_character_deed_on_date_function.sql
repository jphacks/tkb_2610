-- 指定した日本時間の日付に、有効な善行が1件以上あるか調べる。
-- 獲得XPが0の投稿も、投稿ありとして扱う。
create or replace function public.has_character_deed_on_date(
  p_user_id uuid,
  p_character_id uuid,
  p_date date
) returns boolean
language sql
stable
security invoker
set search_path = public
as $$
  select exists (
    select 1
    from public.deeds as d
    where d.user_id = p_user_id
      and d.character_id = p_character_id
      and d.created_at >= (p_date::timestamp at time zone 'Asia/Tokyo')
      and d.created_at < ((p_date + 1)::timestamp at time zone 'Asia/Tokyo')
  );
$$;

revoke all on function public.has_character_deed_on_date(uuid, uuid, date)
  from public, anon, authenticated;

grant execute on function public.has_character_deed_on_date(uuid, uuid, date)
  to service_role;
