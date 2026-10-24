import { Router } from 'express';
import { createCharacter, getEvolution, getHistory, getMyCharacter } from '../controllers/characters.controller.js';
import { requireAuth } from '../middleware/require-auth.js';
export const charactersRoutes = Router();
charactersRoutes.use(requireAuth);
charactersRoutes.get('/history', getHistory);
charactersRoutes.get('/me/evolution', getEvolution);
charactersRoutes.get('/me', getMyCharacter);
charactersRoutes.post('/', createCharacter);
