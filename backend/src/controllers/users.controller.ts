import type { Request, Response } from 'express';
import { changeUserDisplayName, getUserProfile } from '../services/users.service.js';
import { deleteGuestAccount } from '../repositories/game.repository.js';
import { ApiError, authenticatedUserId } from '../lib/api-error.js';
import { displayNameSchema, parseInput } from '../utils/validation.js';

export async function getMe(_request: Request, response: Response): Promise<void> {
  const user = await getUserProfile(authenticatedUserId(response));
  if (!user) throw new ApiError(404, 'USER_NOT_FOUND', 'ユーザーが見つかりません。');
  response.json({ user });
}
export async function updateMe(request: Request, response: Response): Promise<void> {
  const userId = authenticatedUserId(response);
  const input = parseInput(displayNameSchema, request.body);
  const user = await changeUserDisplayName(userId, input.displayName);
  if (!user) throw new ApiError(404, 'USER_NOT_FOUND', 'ユーザーが見つかりません。');
  response.json({ user });
}
export async function deleteMe(_request: Request, response: Response): Promise<void> {
  await deleteGuestAccount(authenticatedUserId(response));
  response.status(204).end();
}
