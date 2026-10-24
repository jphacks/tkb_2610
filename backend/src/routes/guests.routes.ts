import { Router } from "express";
import { createGuest } from "../controllers/guests.controller.js";

export const guestsRoutes = Router();

guestsRoutes.post("/", createGuest);
