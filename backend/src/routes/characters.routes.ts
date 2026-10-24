import { Router } from "express";
import { getMyCharacter } from "../controllers/characters.controller.js";
import { requireAuth } from "../middleware/require-auth.js";

export const charactersRoutes = Router();

charactersRoutes.get("/me", requireAuth, getMyCharacter);
