import express from "express";
import { guestsRoutes } from "./routes/guests.routes.js";
import { usersRoutes } from "./routes/users.routes.js";
import { charactersRoutes } from "./routes/characters.routes.js";

export const app = express();

app.use(express.json());

app.get("/api/health", (_request, response) => {
  response.status(200).json({ status: "ok" });
});

app.use("/api/guests", guestsRoutes);
app.use("/api/users", usersRoutes);
app.use("/api/characters", charactersRoutes);
