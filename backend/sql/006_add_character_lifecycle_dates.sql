-- 生存日数の計算と、死亡・育成終了の記録に使用する。
alter table public.characters
  add column if not exists died_at timestamptz,
  add column if not exists ended_at timestamptz,
  add column if not exists second_evolution_date date;

comment on column public.characters.died_at is 'キャラクターが実際に死亡した日時';
comment on column public.characters.ended_at is '育成終了を記録した日時';
comment on column public.characters.second_evolution_date is '第2進化を達成した日本時間の日付（最終育成日）';
