import {
  findCurrentCharacterByUserId,
  type CurrentCharacterRecord,
} from "../repositories/character.repository.js";
import { getCharacterDeedCount } from "../repositories/deed.repository.js";
import { calculateCharacterLifespan } from "../utils/character-lifespan.js";
import {
  getNextCharacterAvailability,
  type NextCharacterAvailability,
} from "../utils/next-character-availability.js";
import { getTodayDeedStatus, type TodayDeedStatus } from "./deeds.service.js";

export type CurrentCharacterResult = CurrentCharacterRecord & {
  lifespanDays: number;
  deedCount: number;
};

export type CurrentCharacterResponse = NextCharacterAvailability & {
  currentCharacter: CurrentCharacterResult;
  today: TodayDeedStatus;
};

export async function getCurrentCharacter(
  userId: string,
): Promise<CurrentCharacterResponse | null> {
  const character = await findCurrentCharacterByUserId(userId);

  if (!character) {
    return null;
  }

  const now = new Date();
  const [today, deedCount] = await Promise.all([
    getTodayDeedStatus(userId, now),
    getCharacterDeedCount(userId, character.id),
  ]);
  return {
    currentCharacter: {
      ...character,
      lifespanDays: calculateCharacterLifespan(character, now),
      deedCount,
    },
    today,
    ...getNextCharacterAvailability(character, now),
  };
}
