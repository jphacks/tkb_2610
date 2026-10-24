import { randomUUID } from 'node:crypto';
import express from 'express';
import { guestsRoutes } from './routes/guests.routes.js';
import { usersRoutes } from './routes/users.routes.js';
import { charactersRoutes } from './routes/characters.routes.js';
import { createDeedsRoutes } from './routes/deeds.routes.js';
import { CATEGORIES } from './config/categories.js';
import { judgeDeedWithGemini, type JudgeDeed } from './lib/gemini.js';
import { ApiError } from './lib/api-error.js';
import { errorHandler } from './middleware/errors.js';

export function createApp(options: { judgeDeed?: JudgeDeed } = {}) {
  const app = express();
  app.use((_request, response, next) => { response.locals.requestId = randomUUID(); next(); });
  app.use(express.json({ limit: '16kb' }));
  app.get('/api/health', (_request, response) => { response.json({ status: 'ok' }); });
  app.get('/api/categories', (_request, response) => { response.json({ categories: CATEGORIES }); });
  app.use('/api/guests', guestsRoutes);
  app.use('/api/users', usersRoutes);
  app.use('/api/characters', charactersRoutes);
  app.use('/api/deeds', createDeedsRoutes(options.judgeDeed ?? judgeDeedWithGemini));
  app.use((_request, _response, next) => { next(new ApiError(404, 'NOT_FOUND', 'APIが見つかりません。')); });
  app.use(errorHandler);
  return app;
}
export const app = createApp();
