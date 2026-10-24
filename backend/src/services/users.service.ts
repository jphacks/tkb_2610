import {
  findUserProfileById,
  type UserProfile,
  updateUserDisplayName,
  type UpdatedUserName,
} from "../repositories/user.repository.js";
import { findCharacterLifespansByUserId } from "../repositories/character.repository.js";
import { calculateCharacterLifespan } from "../utils/character-lifespan.js";

import { settleCharacterState } from "../repositories/game.repository.js";

export type UserProfileResult = UserProfile & {
  isGuest: boolean;
  longestSurvivalDays: number;
};

export async function getUserProfile(
  userId: string,
): Promise<UserProfileResult | null> {
  await settleCharacterState(userId);
  const user = await findUserProfileById(userId);

  if (!user) {
    return null;
  }

  const characters = await findCharacterLifespansByUserId(userId);
  const now = new Date();
  const longestSurvivalDays = characters.reduce(
    (longest, character) => Math.max(longest, calculateCharacterLifespan(character, now)),
    0,
  );

  return {
    ...user,
    // 初期リリースはゲスト認証のみ。
    isGuest: true,
    longestSurvivalDays,
  };
}

export async function changeUserDisplayName(
  userId: string,
  displayName: string,
): Promise<UpdatedUserName | null> {
  return updateUserDisplayName(userId, displayName);
}
