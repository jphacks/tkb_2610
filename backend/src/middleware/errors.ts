import type { ErrorRequestHandler } from 'express';
import { ZodError } from 'zod';
import { ApiError, traceId } from '../lib/api-error.js';

export const errorHandler: ErrorRequestHandler = (error, _request, response, next) => {
  if (response.headersSent) { next(error); return; }
  let failure: ApiError;
  if (error instanceof ApiError) failure = error;
  else if (error?.type === 'entity.parse.failed') failure = new ApiError(400, 'VALIDATION_ERROR', 'JSONの形式を確認してください。');
  else if (error?.type === 'entity.too.large') failure = new ApiError(413, 'PAYLOAD_TOO_LARGE', '送信データが大きすぎます。');
  else {
    console.error('Request failed', { requestId: traceId(response), kind: error instanceof ZodError ? 'INVALID_DATABASE_RESULT' : 'INTERNAL_ERROR' });
    failure = new ApiError(500, 'INTERNAL_ERROR', '処理に失敗しました。');
  }
  response.status(failure.status).json({ error: { code: failure.code, message: failure.message, requestId: traceId(response) } });
};
