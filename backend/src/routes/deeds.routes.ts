import { Router } from 'express';
import { requireAuth } from '../middleware/require-auth.js';
import { createDeedController, getDeeds, getToday } from '../controllers/deeds.controller.js';
import type { JudgeDeed } from '../lib/gemini.js';

export function createDeedsRoutes(judge: JudgeDeed) {
  const router = Router();
  router.use(requireAuth);
  router.get('/today', getToday);
  router.get('/', getDeeds);
  router.post('/', createDeedController(judge));
  return router;
}
