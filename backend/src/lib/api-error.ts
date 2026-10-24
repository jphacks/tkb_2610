import { randomUUID } from 'node:crypto';
import type { Response } from 'express';

export class ApiError extends Error {
  constructor(public status: number, public code: string, message: string) { super(message); }
}

const domainErrors: Record<string, [number, string]> = {
  USER_NOT_FOUND: [404, 'ユーザーが見つかりません。'],
  CHARACTER_NOT_FOUND: [404, 'キャラクターが見つかりません。'],
  CHARACTER_NOT_ACTIVE: [409, 'このキャラクターには投稿できません。'],
  ACTIVE_CHARACTER_EXISTS: [409, '育成中のキャラクターがいます。'],
  GENERATION_NOT_AVAILABLE: [409, 'まだ次世代を作成できません。'],
  IDEMPOTENCY_CONFLICT: [409, '登録済み、または処理中の投稿IDに別の内容が指定されました。'],
  REQUEST_IN_PROGRESS: [409, 'この投稿は処理中です。同じ投稿IDで後から再試行してください。'],
  REQUEST_NOT_FOUND: [409, '投稿の受付状態を確認できませんでした。'],
};
export function throwDomainError(code: string): never {
  const [status, message] = domainErrors[code] ?? [500, '処理に失敗しました。'];
  throw new ApiError(status, code in domainErrors ? code : 'INTERNAL_ERROR', message);
}
export function authenticatedUserId(response: Response): string {
  const id = response.locals.auth?.userId;
  if (!id) throw new ApiError(401, 'UNAUTHENTICATED', '認証が必要です。');
  return id;
}
export function traceId(response: Response): string {
  return response.locals.requestId ?? randomUUID();
}
