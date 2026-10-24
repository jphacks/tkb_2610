import { randomUUID } from "node:crypto";
import type { Request, Response } from "express";
import { z } from "zod";
import {
  changeUserDisplayName,
  getUserProfile,
} from "../services/users.service.js";

const updateDisplayNameSchema = z.object({
  displayName: z.string().trim().min(1).max(20).refine(
    (value) => !/[\u0000-\u001f\u007f]/.test(value),
    "displayName must not contain control characters",
  ),
}).strict();

export async function getMe(
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
    const user = await getUserProfile(userId);

    if (!user) {
      response.status(404).json({
        error: {
          code: "USER_NOT_FOUND",
          message: "ユーザーが見つかりません。",
          requestId,
        },
      });
      return;
    }

    response.status(200).json({ user });
  } catch (error) {
    console.error("User profile lookup failed", { requestId, error });
    response.status(500).json({
      error: {
        code: "INTERNAL_ERROR",
        message: "プロフィールの取得に失敗しました。",
        requestId,
      },
    });
  }
}

export async function updateMe(
  request: Request,
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

  const bodyResult = updateDisplayNameSchema.safeParse(request.body);
  if (!bodyResult.success) {
    response.status(400).json({
      error: {
        code: "VALIDATION_ERROR",
        message: "プレイヤー名は1〜20文字で入力してください。",
        requestId,
      },
    });
    return;
  }

  try {
    const user = await changeUserDisplayName(userId, bodyResult.data.displayName);

    if (!user) {
      response.status(404).json({
        error: {
          code: "USER_NOT_FOUND",
          message: "ユーザーが見つかりません。",
          requestId,
        },
      });
      return;
    }

    response.status(200).json({ user });
  } catch (error) {
    console.error("User display name update failed", { requestId, error });
    response.status(500).json({
      error: {
        code: "INTERNAL_ERROR",
        message: "プレイヤー名の変更に失敗しました。",
        requestId,
      },
    });
  }
}
