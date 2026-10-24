create or replace function public.register_guest(
  p_user_id uuid,
  p_character_id uuid,
  p_session_id uuid,
  p_display_name text,
  p_idempotency_key_hash text,
  p_request_hash text,
  p_token_hash text,
  p_expires_at timestamptz
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  existing_request public.guest_registration_requests%rowtype;
  response_body jsonb;
  created_at timestamptz := now();
begin
  -- Prevent two simultaneous requests with the same key from creating two users.
  perform pg_advisory_xact_lock(hashtextextended(p_idempotency_key_hash, 0));

  select *
    into existing_request
    from public.guest_registration_requests
   where idempotency_key_hash = p_idempotency_key_hash;

  if found then
    if existing_request.request_hash <> p_request_hash then
      return jsonb_build_object('conflict', true);
    end if;

    return jsonb_build_object(
      'conflict', false,
      'body', existing_request.response_body
    );
  end if;

  insert into public.users (id, display_name, created_at)
  values (p_user_id, p_display_name, created_at);

  insert into public.characters (
    id,
    user_id,
    generation,
    image_id,
    hp,
    max_hp,
    total_xp,
    level,
    evolution_stage,
    status,
    created_at
  ) values (
    p_character_id,
    p_user_id,
    1,
    'base_01',
    100,
    100,
    0,
    1,
    0,
    'alive',
    created_at
  );

  insert into public.guest_sessions (
    id,
    user_id,
    token_hash,
    created_at,
    expires_at
  ) values (
    p_session_id,
    p_user_id,
    p_token_hash,
    created_at,
    p_expires_at
  );

  response_body := jsonb_build_object(
    'user', jsonb_build_object(
      'id', p_user_id,
      'displayName', p_display_name,
      'createdAt', created_at
    ),
    'currentCharacter', jsonb_build_object(
      'id', p_character_id,
      'generation', 1,
      'imageId', 'base_01',
      'hp', 100,
      'maxHp', 100,
      'totalXp', 0,
      'level', 1,
      'evolutionStage', 0,
      'status', 'alive',
      'createdAt', created_at
    )
  );

  insert into public.guest_registration_requests (
    idempotency_key_hash,
    request_hash,
    user_id,
    response_body
  ) values (
    p_idempotency_key_hash,
    p_request_hash,
    p_user_id,
    response_body
  );

  return jsonb_build_object('conflict', false, 'body', response_body);
end;
$$;

revoke all on function public.register_guest(
  uuid, uuid, uuid, text, text, text, text, timestamptz
) from public;

grant execute on function public.register_guest(
  uuid, uuid, uuid, text, text, text, text, timestamptz
) to service_role;
