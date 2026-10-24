import type { Request, Response } from 'express';
import type { JudgeDeed } from '../lib/gemini.js';
import { authenticatedUserId } from '../lib/api-error.js';
import { getTodayDeedStatus, submitDeed } from '../services/deeds.service.js';
import { listDeeds } from '../repositories/deed.repository.js';
import { deedInputSchema, deedListSchema, parseInput } from '../utils/validation.js';

export function createDeedController(judge: JudgeDeed) {
  return async (request: Request, response: Response): Promise<void> => {
    const userId = authenticatedUserId(response);
    const input = parseInput(deedInputSchema, request.body);
    const result = await submitDeed(userId, input.requestId, input.content, judge);
    response.status(result.httpStatus).json(result.body);
  };
}
export async function getToday(_request: Request, response: Response): Promise<void> {
  response.json(await getTodayDeedStatus(authenticatedUserId(response)));
}
export async function getDeeds(request: Request, response: Response): Promise<void> {
  const userId = authenticatedUserId(response);
  const input = parseInput(deedListSchema, request.query);
  response.json(await listDeeds(userId, input.limit, input.offset, input.characterId));
}
