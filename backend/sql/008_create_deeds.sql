-- キャラクターと投稿ユーザーの組み合わせを、外部キーで確認するために必要。
create unique index if not exists characters_id_user_id_key
  on public.characters(id, user_id);

create table if not exists public.deeds (
  id uuid primary key,
  user_id uuid not null references public.users(id) on delete cascade,
  character_id uuid not null,
  request_id uuid not null,
  content text not null check (length(btrim(content)) > 0),
  category text not null check (category in (
    'kindness', 'environment', 'gratitude', 'courage',
    'cooperation', 'honesty', 'self_care'
  )),
  praise text not null,
  earned_xp integer not null check (earned_xp >= 0),
  earned_category_points integer not null check (earned_category_points >= 0),
  recovered_hp integer not null check (recovered_hp >= 0),
  created_at timestamptz not null default now(),
  unique (user_id, request_id),
  foreign key (character_id, user_id)
    references public.characters(id, user_id) on delete cascade
);

-- 今日の状況と、ユーザー全体の善行履歴を取得するための索引。
create index if not exists deeds_user_created_at_idx
  on public.deeds(user_id, created_at desc, id desc);

-- キャラクター別の善行履歴を取得するための索引。
create index if not exists deeds_character_created_at_idx
  on public.deeds(character_id, created_at desc, id desc);

-- アプリからの直接操作は許可せず、Node.jsの管理用キー経由で操作する。
alter table public.deeds enable row level security;
