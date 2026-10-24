create table if not exists public.users (
  id uuid primary key,
  display_name varchar(20) not null,
  created_at timestamptz not null default now()
);
