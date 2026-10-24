-- 日付はすべて日本時間の日付を渡す。
-- 後でキャラクターをロックしてから、この関数で未処理日を調べる。
create or replace function public.get_pending_penalty_dates(
  p_created_date date,
  p_last_penalty_applied_date date,
  p_second_evolution_date date,
  p_today date
) returns table (penalty_date date)
language sql
immutable
security invoker
set search_path = public
as $$
  with bounds as (
    select
      -- 作成当日と、すでに確認済みの日付は飛ばす。
      greatest(
        p_created_date,
        coalesce(p_last_penalty_applied_date, p_created_date)
      ) + 1 as start_date,
      -- 今日と、第2進化達成日より後の日付は対象外。
      least(
        p_today - 1,
        coalesce(p_second_evolution_date, p_today - 1)
      ) as end_date
  )
  select b.start_date + days.day_offset as penalty_date
  from bounds as b
  cross join lateral generate_series(0, b.end_date - b.start_date) as days(day_offset)
  order by penalty_date;
$$;

revoke all on function public.get_pending_penalty_dates(date, date, date, date)
  from public, anon, authenticated;

grant execute on function public.get_pending_penalty_dates(date, date, date, date)
  to service_role;
