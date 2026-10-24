import { DAILY_XP_LIMIT } from "../config/game.js";
import { getDeedSummary } from "../repositories/deed.repository.js";
import { getJstDayRange } from "../utils/jst-day-range.js";

export type TodayDeedStatus = {
  date: string;
  deedCount: number;
  earnedXp: number;
  xpLimit: number;
  remainingXp: number;
  goalAchieved: boolean;
};

export async function getTodayDeedStatus(
  userId: string,
  now: Date = new Date(),
): Promise<TodayDeedStatus> {
  const dayRange = getJstDayRange(now);
  const summary = await getDeedSummary(userId, dayRange);

  return {
    date: dayRange.date,
    deedCount: summary.deedCount,
    earnedXp: summary.earnedXp,
    xpLimit: DAILY_XP_LIMIT,
    remainingXp: Math.max(0, DAILY_XP_LIMIT - summary.earnedXp),
    goalAchieved: summary.deedCount > 0,
  };
}
