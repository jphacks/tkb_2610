import { z } from 'zod';
import { callRpc } from '../lib/rpc.js';
import type { DeedJudgement } from '../lib/gemini.js';

export const savedResponseSchema = z.object({ httpStatus: z.union([z.literal(201), z.literal(409), z.literal(422)]), body: z.unknown() });
const beginSchema = z.union([
  savedResponseSchema.extend({ kind: z.literal('replay') }),
  z.object({ kind: z.literal('ready'), characterId: z.uuid(), displayName: z.string() }),
]);
export async function beginDeedRequest(userId: string, requestId: string, content: string, leaseToken: string) {
  return beginSchema.parse(await callRpc('begin_deed_request', {
    p_user_id: userId, p_request_id: requestId, p_content: content, p_lease_token: leaseToken,
  }));
}
export async function finishDeedRequest(userId: string, requestId: string, leaseToken: string, judgement: DeedJudgement) {
  return savedResponseSchema.parse(await callRpc('finish_deed_request', {
    p_user_id: userId, p_request_id: requestId, p_lease_token: leaseToken,
    p_valid: judgement.valid, p_category: judgement.category, p_praise: judgement.praise,
  }));
}
export async function releaseDeedRequest(userId: string, requestId: string, leaseToken: string): Promise<void> {
  await callRpc('release_deed_request', { p_user_id: userId, p_request_id: requestId, p_lease_token: leaseToken });
}
