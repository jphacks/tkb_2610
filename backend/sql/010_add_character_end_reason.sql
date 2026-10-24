alter table public.characters
  add column if not exists end_reason text
    check (end_reason in ('death', 'second_evolution'));

-- すでに死亡・育成終了しているキャラクターには、状態に対応する理由を入れる。
-- 育成中のキャラクターはnullのままにする。
update public.characters
set end_reason = case
  when status = 'dead' then 'death'
  when status = 'retired' then 'second_evolution'
end
where end_reason is null
  and status in ('dead', 'retired');

comment on column public.characters.end_reason is '育成終了理由：death（死亡）、second_evolution（第2進化による終了）。育成中はnull';
