import { randomUUID } from "node:crypto";
import type { Request, Response } from "express";
import { z } from "zod";
import { createGuestAccount } from "../services/auth.service.js";

const guestRequestSchema = z.object({
  displayName: z.string().trim().min(1).max(20).refine(
    (value) => !/[\u0000-\u001f\u007f]/.test(value),
    "displayName must not contain control characters",
  ),
}).strict();

export async function createGuest(request: Request, response: Response): Promise<void> {
  const responseRequestId = randomUUID();
  const bodyResult = guestRequestSchema.safeParse(request.body);

  if (!bodyResult.success) {
    response.status(400).json({
      error: {
        code: "VALIDATION_ERROR",
        message: "入力内容を確認してください。",
        requestId: responseRequestId,
      },
    });
    return;
  }

  try {
    const result = await createGuestAccount({
      displayName: bodyResult.data.displayName,
    });

    if (result.conflict) {
      response.status(409).json({
        error: {
          code: "IDEMPOTENCY_CONFLICT",
          message: "同じIdempotency-Keyで異なる内容が送信されました。",
          requestId: responseRequestId,
        },
      });
      return;
    }

    response.status(201).json(result.body);
  } catch (error) {
    console.error("Guest registration failed", { requestId: responseRequestId, error });
    response.status(500).json({
      error: {
        code: "INTERNAL_ERROR",
        message: "ゲスト登録に失敗しました。",
        requestId: responseRequestId,
      },
    });
  }
}
