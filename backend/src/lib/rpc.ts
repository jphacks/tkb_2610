import { z } from 'zod';
import { supabase } from './supabase.js';
import { ApiError, throwDomainError } from './api-error.js';

export async function callRpc(name: string, parameters: Record<string, unknown>): Promise<unknown> {
  const { data, error } = await supabase.rpc(name, parameters);
  if (error) {
    console.error('Database RPC failed', { operation: name, code: error.code });
    throw new ApiError(500, 'INTERNAL_ERROR', 'データを処理できませんでした。');
  }
  const result = z.object({ errorCode: z.string().optional() }).passthrough().safeParse(data);
  if (result.success && result.data.errorCode) throwDomainError(result.data.errorCode);
  return data;
}
