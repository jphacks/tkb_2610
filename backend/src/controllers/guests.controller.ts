import type { Request, Response } from 'express';
import { createGuestAccount } from '../services/auth.service.js';
import { ApiError } from '../lib/api-error.js';
import { displayNameSchema, parseInput } from '../utils/validation.js';
export async function createGuest(request: Request, response: Response): Promise<void> {
  const input = parseInput(displayNameSchema, request.body);
  const result = await createGuestAccount(input);
  if (result.conflict) throw new ApiError(500, 'INTERNAL_ERROR', 'ゲスト登録に失敗しました。');
  response.status(201).json(result.body);
}
