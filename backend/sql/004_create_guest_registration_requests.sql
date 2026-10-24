create table if not exists public.guest_registration_requests (
  idempotency_key_hash text primary key,
  request_hash text not null,
  user_id uuid not null references public.users(id) on delete cascade,
  response_body jsonb not null,
  created_at timestamptz not null default now()
);

create index if not exists guest_registration_requests_user_id_idx
  on public.guest_registration_requests(user_id);
