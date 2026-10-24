import { createHash, randomUUID } from "node:crypto";
import type { NextFunction, Request, Response } from "express";
import { supabase } from "../lib/supabase.js";

export async function requireAuth(
  request: Request,
  response: Response,
  next: NextFunction,
): Promise<void> {
  const authorization = request.header("Authorization");
  const match = authorization?.match(/^Bearer ([A-Za-z0-9_-]+)$/);

  if (!match) {
    response.status(401).json({
      error: {
        code: "UNAUTHENTICATED",
        message: "認証が必要です。",
        requestId: randomUUID(),
      },
    });
    return;
  }

  const tokenHash = createHash("sha256").update(match[1]).digest("hex");
  const { data, error } = await supabase
    .from("guest_sessions")
    .select("id, user_id")
    .eq("token_hash", tokenHash)
    .is("revoked_at", null)
    .gt("expires_at", new Date().toISOString())
    .maybeSingle();

  if (error) {
    console.error("Session lookup failed", { requestId: randomUUID(), error });
    response.status(500).json({
      error: {
        code: "INTERNAL_ERROR",
        message: "認証状態を確認できませんでした。",
        requestId: randomUUID(),
      },
    });
    return;
  }

  if (!data) {
    response.status(401).json({
      error: {
        code: "UNAUTHENTICATED",
        message: "認証が必要です。",
        requestId: randomUUID(),
      },
    });
    return;
  }

  response.locals.auth = {
    userId: data.user_id,
    sessionId: data.id,
  };
  next();
}
