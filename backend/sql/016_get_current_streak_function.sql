begin;
-- 今日未投稿なら昨日から遡り、有効な善行を連続して投稿した日本時間の暦日数を返す。
create or replace function public.get_current_streak_days(p_user_id uuid)
returns integer language sql stable security invoker set search_path=public as $$
  with today as (
    select (now() at time zone 'Asia/Tokyo')::date as d
  ), posted_days as (
    select distinct (created_at at time zone 'Asia/Tokyo')::date as d
    from public.deeds, today
    where user_id=p_user_id and created_at < ((today.d+1)::timestamp at time zone 'Asia/Tokyo')
  ), anchor as (
    select case when exists(select 1 from posted_days, today where posted_days.d=today.d)
      then today.d else today.d-1 end as d from today
  ), ranked as (
    select d, row_number() over(order by d desc) as n from posted_days
  )
  select count(*)::integer from ranked, anchor where ranked.d=anchor.d-(ranked.n-1)::integer;
$$;
revoke all on function public.get_current_streak_days(uuid) from public,anon,authenticated;
grant execute on function public.get_current_streak_days(uuid) to service_role;
commit;
