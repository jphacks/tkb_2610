import { z } from "zod";
import { supabase } from "../lib/supabase.js";
import type { JstDayRange } from "../utils/jst-day-range.js";

const deedSummarySchema = z.object({
  deed_count: z.number().int().nonnegative().safe(),
  earned_xp: z.number().int().nonnegative().safe(),
});

export type DeedSummary = {
  deedCount: number;
  earnedXp: number;
};

export async function getDeedSummary(
  userId: string,
  dayRange: JstDayRange,
): Promise<DeedSummary> {
  const { data, error } = await supabase
    .rpc("get_deed_summary", {
      p_user_id: userId,
      p_start_at: dayRange.startAt,
      p_end_before: dayRange.endBefore,
    })
    .single();

  if (error) {
    throw new Error(`Deed summary lookup failed: ${error.message}`);
  }

  const summary = deedSummarySchema.parse(data);
  return {
    deedCount: summary.deed_count,
    earnedXp: summary.earned_xp,
  };
}

export async function getCharacterDeedCount(
  userId: string,
  characterId: string,
): Promise<number> {
  const { count, error } = await supabase
    .from("deeds")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userId)
    .eq("character_id", characterId);

  if (error) {
    throw new Error(`Character deed count lookup failed: ${error.message}`);
  }

  if (count === null) {
    throw new Error("Character deed count was not returned");
  }

  return count;
}
