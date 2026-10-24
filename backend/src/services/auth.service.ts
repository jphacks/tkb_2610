import { createHash, randomBytes, randomUUID } from "node:crypto";
import { registerGuest } from "../repositories/auth.repository.js";

type CreateGuestAccountInput = {
  displayName: string;
};

export async function createGuestAccount(input: CreateGuestAccountInput) {
  const sessionToken = randomBytes(32).toString("base64url");
  const internalRequestKey = randomUUID();

  const result = await registerGuest({
    userId: randomUUID(),
    characterId: randomUUID(),
    sessionId: randomUUID(),
    displayName: input.displayName,
    idempotencyKeyHash: createHash("sha256").update(internalRequestKey).digest("hex"),
    requestHash: createHash("sha256")
      .update(JSON.stringify({ displayName: input.displayName }))
      .digest("hex"),
    tokenHash: createHash("sha256").update(sessionToken).digest("hex"),
    expiresAt: new Date(Date.now() + 90 * 24 * 60 * 60 * 1000).toISOString(),
  });

  if (result.conflict) return result;

  return {
    conflict: false as const,
    body: {
      ...result.body,
      sessionToken,
    },
  };
}
