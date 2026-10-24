alter table public.characters
  -- 進化前は、決まっていない属性をnullで保存する。
  add column if not exists first_evolution_category text
    check (first_evolution_category in (
      'kindness', 'environment', 'gratitude', 'courage',
      'cooperation', 'honesty', 'self_care'
    )),
  add column if not exists second_evolution_category text
    check (second_evolution_category in (
      'kindness', 'environment', 'gratitude', 'courage',
      'cooperation', 'honesty', 'self_care'
    )),
  -- 各カテゴリのポイントを、一つのJSONオブジェクトに保存する。
  add column if not exists category_points jsonb not null default '{
    "kindness": 0,
    "environment": 0,
    "gratitude": 0,
    "courage": 0,
    "cooperation": 0,
    "honesty": 0,
    "self_care": 0
  }'::jsonb
    check (jsonb_typeof(category_points) = 'object');

comment on column public.characters.first_evolution_category is '第1進化で決まった属性のカテゴリID';
comment on column public.characters.second_evolution_category is '第2進化で決まった属性のカテゴリID';
comment on column public.characters.category_points is 'カテゴリIDをキーとした7属性のポイント（初期値はすべて0）';
