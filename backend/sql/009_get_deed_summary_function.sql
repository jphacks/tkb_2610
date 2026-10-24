-- 指定ユーザーの、指定期間内の善行件数と獲得XPを集計する。
-- 開始時刻は含め、終了時刻は含めない。
create or replace function public.get_deed_summary(
  p_user_id uuid,
  p_start_at timestamptz,
  p_end_before timestamptz
) returns table (
  deed_count bigint,
  earned_xp bigint
)
language sql
stable
security invoker
set search_path = public
as $$
  select
    count(*) as deed_count,
    coalesce(sum(d.earned_xp), 0) as earned_xp
  from public.deeds as d
  where d.user_id = p_user_id
    and d.created_at >= p_start_at
    and d.created_at < p_end_before;
$$;

-- ユーザーIDを指定できるため、バックエンドの管理用キーからだけ呼び出せるようにする。
revoke all on function public.get_deed_summary(uuid, timestamptz, timestamptz)
  from public, anon, authenticated;

grant execute on function public.get_deed_summary(uuid, timestamptz, timestamptz)
  to service_role;
