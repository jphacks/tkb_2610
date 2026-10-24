import { randomUUID } from 'node:crypto';
import type { Request, Response } from 'express';
import { getCurrentCharacter, getEvolutionProgress } from '../services/characters.service.js';
import { createNextCharacter, getCharacterHistory } from '../repositories/game.repository.js';
import { ApiError, authenticatedUserId } from '../lib/api-error.js';
import { paginationSchema, parseInput } from '../utils/validation.js';

export async function getMyCharacter(_request: Request, response: Response): Promise<void> {
  const result = await getCurrentCharacter(authenticatedUserId(response));
  if (!result) throw new ApiError(404, 'CHARACTER_NOT_FOUND', 'キャラクターが見つかりません。');
  response.json(result);
}
export async function createCharacter(request: Request, response: Response): Promise<void> {
  if (request.body !== undefined && (typeof request.body !== 'object' || request.body === null || Array.isArray(request.body) || Object.keys(request.body).length)) {
    throw new ApiError(400, 'VALIDATION_ERROR', 'このAPIにリクエスト本文は不要です。');
  }
  response.status(201).json(await createNextCharacter(authenticatedUserId(response), randomUUID()));
}
export async function getHistory(request: Request, response: Response): Promise<void> {
  const userId = authenticatedUserId(response);
  const input = parseInput(paginationSchema, request.query);
  response.json(await getCharacterHistory(userId, input.limit, input.offset));
}
export async function getEvolution(_request: Request, response: Response): Promise<void> {
  response.json(await getEvolutionProgress(authenticatedUserId(response)));
}
