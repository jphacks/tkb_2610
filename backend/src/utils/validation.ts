import { z } from 'zod';
import { DEED_CONTENT_MAX_LENGTH } from '../config/game.js';
import { ApiError } from '../lib/api-error.js';

export const displayNameSchema = z.object({ displayName: z.string().trim().min(1).max(20)
  .refine((value) => !/[\u0000-\u001f\u007f]/.test(value)) }).strict();
export const deedInputSchema = z.object({
  content: z.string().trim().min(1).max(DEED_CONTENT_MAX_LENGTH)
    .refine((value) => !/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/.test(value)),
  requestId: z.uuid(),
}).strict();
const integerQuery = (fallback: number, min: number, max: number) => z.preprocess(
  (value) => value === undefined ? fallback : typeof value === 'string' && /^\d+$/.test(value) ? Number(value) : value,
  z.number().int().safe().min(min).max(max),
);
export const paginationSchema = z.object({ limit: integerQuery(20, 1, 50), offset: integerQuery(0, 0, 2147483647) }).strict();
export const deedListSchema = paginationSchema.extend({ characterId: z.uuid().optional() });
export function parseInput<T>(schema: z.ZodType<T>, value: unknown): T {
  const parsed = schema.safeParse(value);
  if (!parsed.success) throw new ApiError(400, 'VALIDATION_ERROR', '入力内容を確認してください。');
  return parsed.data;
}
