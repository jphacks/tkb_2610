import { Router } from "express";
import { getMe, updateMe } from "../controllers/users.controller.js";
import { requireAuth } from "../middleware/require-auth.js";

export const usersRoutes = Router();

usersRoutes.get("/me", requireAuth, getMe);
usersRoutes.put("/me", requireAuth, updateMe);
