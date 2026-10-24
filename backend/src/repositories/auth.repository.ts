import { supabase } from "../lib/supabase.js";

export type RegisterGuestInput = {
  userId: string;
  characterId: string;
  sessionId: string;
  displayName: string;
  idempotencyKeyHash: string;
  requestHash: string;
  tokenHash: string;
  expiresAt: string;
};

export type RegisterGuestResponseBody = {
  user: {
    id: string;
    displayName: string;
    createdAt: string;
  };
  currentCharacter: {
    id: string;
    generation: number;
    imageId: string;
    hp: number;
    maxHp: number;
    totalXp: number;
    level: number;
    evolutionStage: number;
    status: "alive";
    createdAt: string;
  };
};

export type RegisterGuestResult =
  | { conflict: true }
  | { conflict: false; body: RegisterGuestResponseBody };

export async function registerGuest(
  input: RegisterGuestInput,
): Promise<RegisterGuestResult> {
  const { data, error } = await supabase.rpc("register_guest", {
    p_user_id: input.userId,
    p_character_id: input.characterId,
    p_session_id: input.sessionId,
    p_display_name: input.displayName,
    p_idempotency_key_hash: input.idempotencyKeyHash,
    p_request_hash: input.requestHash,
    p_token_hash: input.tokenHash,
    p_expires_at: input.expiresAt,
  });

  if (error) {
    throw new Error(`register_guest RPC failed: ${error.message}`);
  }

  if (!data || typeof data !== "object") {
    throw new Error("register_guest RPC returned an invalid result");
  }

  const result = data as { conflict?: unknown; body?: unknown };

  if (result.conflict === true) {
    return { conflict: true };
  }

  if (result.conflict !== false || !result.body || typeof result.body !== "object") {
    throw new Error("register_guest RPC returned an invalid result");
  }

  return {
    conflict: false,
    body: result.body as RegisterGuestResponseBody,
  };
}
