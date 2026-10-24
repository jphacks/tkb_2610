import { findCurrentCharacterByUserId, type CurrentCharacterRecord } from '../repositories/character.repository.js';
import { getCharacterDeedCount } from '../repositories/deed.repository.js';
import { getCurrentStreakDays, getGameConfig, settleCharacterState } from '../repositories/game.repository.js';
import { calculateCharacterLifespan } from '../utils/character-lifespan.js';
import { getNextCharacterAvailability, type NextCharacterAvailability } from '../utils/next-character-availability.js';
import { getTodayDeedStatus, type TodayDeedStatus } from './deeds.service.js';
import { ApiError } from '../lib/api-error.js';

export type CurrentCharacterResult = Omit<CurrentCharacterRecord, 'secondEvolutionPoints'> & { lifespanDays: number; deedCount: number };
export type CurrentCharacterResponse = NextCharacterAvailability & {
  currentCharacter: CurrentCharacterResult; today: TodayDeedStatus; currentStreakDays: number;
};
export async function getCurrentCharacter(userId: string): Promise<CurrentCharacterResponse | null> {
  await settleCharacterState(userId);
  const character = await findCurrentCharacterByUserId(userId);
  if (!character) return null;
  const now = new Date();
  const [today, deedCount, currentStreakDays] = await Promise.all([
    getTodayDeedStatus(userId, now), getCharacterDeedCount(userId, character.id), getCurrentStreakDays(userId),
  ]);
  const { secondEvolutionPoints: _points, ...publicCharacter } = character;
  return { currentCharacter: { ...publicCharacter, lifespanDays: calculateCharacterLifespan(character, now), deedCount },
    today, currentStreakDays, ...getNextCharacterAvailability(character, now) };
}
export async function getEvolutionProgress(userId: string) {
  await settleCharacterState(userId);
  const [character, config] = await Promise.all([findCurrentCharacterByUserId(userId), getGameConfig()]);
  if (!character) throw new ApiError(404, 'CHARACTER_NOT_FOUND', 'キャラクターが見つかりません。');
  const nextEvolutionXp = character.evolutionStage >= 2 ? null
    : character.evolutionStage === 0 ? config.firstEvolutionXp : config.secondEvolutionXp;
  return { characterId: character.id, evolutionStage: character.evolutionStage,
    firstEvolutionCategory: character.firstEvolutionCategory, secondEvolutionCategory: character.secondEvolutionCategory,
    imageId: character.imageId, totalXp: character.totalXp, nextEvolutionXp,
    remainingXp: nextEvolutionXp === null ? null : Math.max(0, nextEvolutionXp - character.totalXp),
    categoryPoints: character.evolutionStage === 1 ? character.secondEvolutionPoints : character.categoryPoints };
}
