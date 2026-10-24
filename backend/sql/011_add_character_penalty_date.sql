alter table public.characters
  add column if not exists last_penalty_applied_date date;

-- 作成当日はペナルティ対象外なので、既存キャラクターの確認開始地点を作成日にする。
-- 今日の日付で埋めると、過去の未処理日を飛ばしてしまうため、作成日を使う。
update public.characters
set last_penalty_applied_date = (created_at at time zone 'Asia/Tokyo')::date
where last_penalty_applied_date is null;

comment on column public.characters.last_penalty_applied_date is
  '未投稿ペナルティを確認済みの最終日（日本時間）。新規キャラクターでnullの場合は作成日から確認を始める';
