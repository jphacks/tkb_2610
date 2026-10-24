create table if not exists public.characters (
  id uuid primary key,
  user_id uuid not null references public.users(id) on delete cascade,
  generation integer not null check (generation >= 1),
  image_id text not null,
  hp integer not null default 100 check (hp >= 0),
  max_hp integer not null default 100 check (max_hp > 0),
  total_xp integer not null default 0 check (total_xp >= 0),
  level integer not null default 1 check (level >= 1),
  evolution_stage integer not null default 0 check (evolution_stage between 0 and 2),
  status text not null default 'alive'
    check (status in ('alive', 'dead', 'retired')),
  created_at timestamptz not null default now(),
  unique (user_id, generation),
  check (hp <= max_hp)
);

create unique index if not exists characters_one_alive_per_user
  on public.characters(user_id)
  where status = 'alive';
