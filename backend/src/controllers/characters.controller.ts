import { randomUUID } from "node:crypto";
import type { Request, Response } from "express";
import { getCurrentCharacter } from "../services/characters.service.js";

export async function getMyCharacter(
  _request: Request,
  response: Response<unknown, Express.Locals>,
): Promise<void> {
  const requestId = randomUUID();
  const userId = response.locals.auth?.userId;

  if (!userId) {
    response.status(401).json({
      error: {
        code: "UNAUTHENTICATED",
        message: "認証が必要です。",
        requestId,
      },
    });
    return;
  }

  try {
    const result = await getCurrentCharacter(userId);

    if (!result) {
      response.status(404).json({
        error: {
          code: "CHARACTER_NOT_FOUND",
          message: "キャラクターが見つかりません。",
          requestId,
        },
      });
      return;
    }

    response.status(200).json(result);
  } catch (error) {
    console.error("Current character lookup failed", { requestId, error });
    response.status(500).json({
      error: {
        code: "INTERNAL_ERROR",
        message: "キャラクターの取得に失敗しました。",
        requestId,
      },
    });
  }
}
