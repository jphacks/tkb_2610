import { createHash } from 'node:crypto';
import type { NextFunction, Request, Response } from 'express';
import { supabase } from '../lib/supabase.js';
import { ApiError, traceId } from '../lib/api-error.js';

export async function requireAuth(request: Request, response: Response, next: NextFunction): Promise<void> {
  const match = request.header('Authorization')?.match(/^Bearer ([A-Za-z0-9_-]+)$/);
  if (!match) throw new ApiError(401, 'UNAUTHENTICATED', '認証が必要です。');
  const { data, error } = await supabase.from('guest_sessions').select('id, user_id')
    .eq('token_hash', createHash('sha256').update(match[1]).digest('hex'))
    .is('revoked_at', null).gt('expires_at', new Date().toISOString()).maybeSingle();
  if (error) {
    console.error('Session lookup failed', { requestId: traceId(response), code: error.code });
    throw new ApiError(500, 'INTERNAL_ERROR', '認証状態を確認できませんでした。');
  }
  if (!data) throw new ApiError(401, 'UNAUTHENTICATED', '認証が必要です。');
  response.locals.auth = { userId: data.user_id, sessionId: data.id };
  next();
}
