import { Router } from 'express';
import { deleteMe, getMe, updateMe } from '../controllers/users.controller.js';
import { requireAuth } from '../middleware/require-auth.js';
export const usersRoutes = Router();
usersRoutes.use(requireAuth);
usersRoutes.get('/me', getMe);
usersRoutes.put('/me', updateMe);
usersRoutes.delete('/me', deleteMe);
