import { randomUUID } from 'node:crypto';
import { getDeedSummary } from '../repositories/deed.repository.js';
import { getGameConfig } from '../repositories/game.repository.js';
import { beginDeedRequest, finishDeedRequest, releaseDeedRequest } from '../repositories/deed-request.repository.js';
import { getJstDayRange } from '../utils/jst-day-range.js';
import { judgementSchema, type JudgeDeed } from '../lib/gemini.js';
import { ApiError } from '../lib/api-error.js';

export type TodayDeedStatus = {
  date: string; deedCount: number; earnedXp: number; xpLimit: number; remainingXp: number; goalAchieved: boolean;
};
export async function getTodayDeedStatus(userId: string, now: Date = new Date()): Promise<TodayDeedStatus> {
  const range = getJstDayRange(now);
  const [summary, config] = await Promise.all([getDeedSummary(userId, range), getGameConfig()]);
  return { date: range.date, ...summary, xpLimit: config.dailyXpLimit,
    remainingXp: Math.max(0, config.dailyXpLimit - summary.earnedXp), goalAchieved: summary.deedCount > 0 };
}
export async function submitDeed(userId: string, requestId: string, content: string, judge: JudgeDeed) {
  const leaseToken = randomUUID();
  const reservation = await beginDeedRequest(userId, requestId, content, leaseToken);
  if (reservation.kind === 'replay') return reservation;
  let judgement;
  try { judgement = judgementSchema.parse(await judge(content, reservation.displayName)); }
  catch {
    try { await releaseDeedRequest(userId, requestId, leaseToken); }
    catch { console.error('Deed lease release failed', { leaseToken }); }
    throw new ApiError(503, 'AI_UNAVAILABLE', 'AI判定を利用できませんでした。同じ投稿IDで再試行してください。');
  }
  return finishDeedRequest(userId, requestId, leaseToken, judgement);
}
