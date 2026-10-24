import {
  findCurrentCharacterByUserId,
  type CurrentCharacterRecord,
} from "../repositories/character.repository.js";
import { calculateCharacterLifespan } from "../utils/character-lifespan.js";
import {
  getNextCharacterAvailability,
  type NextCharacterAvailability,
} from "../utils/next-character-availability.js";

export type CurrentCharacterResult = CurrentCharacterRecord & {
  lifespanDays: number;
};

export type CurrentCharacterResponse = NextCharacterAvailability & {
  currentCharacter: CurrentCharacterResult;
};

export async function getCurrentCharacter(
  userId: string,
): Promise<CurrentCharacterResponse | null> {
  const character = await findCurrentCharacterByUserId(userId);

  if (!character) {
    return null;
  }

  const now = new Date();
  return {
    currentCharacter: {
      ...character,
      lifespanDays: calculateCharacterLifespan(character, now),
    },
    ...getNextCharacterAvailability(character, now),
  };
}
