import { z } from "zod";
import { ApiError } from "../lib/api-error.js";
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

const deedRowSchema = z.object({
  id: z.uuid(), character_id: z.uuid(), content: z.string(), category: z.string(), praise: z.string(),
  earned_xp: z.number().int().nonnegative(), earned_category_points: z.number().int().nonnegative(),
  recovered_hp: z.number().int().nonnegative(), created_at: z.string(),
});
export async function listDeeds(userId: string, limit: number, offset: number, characterId?: string) {
  if (characterId) {
    const { data, error } = await supabase.from('characters').select('id').eq('id', characterId).eq('user_id', userId).maybeSingle();
    if (error) throw new Error('Character ownership lookup failed');
    if (!data) throw new ApiError(404, 'CHARACTER_NOT_FOUND', 'キャラクターが見つかりません。');
  }
  let query = supabase.from('deeds').select('id, character_id, content, category, praise, earned_xp, earned_category_points, recovered_hp, created_at', { count: 'exact' })
    .eq('user_id', userId).order('created_at', { ascending: false }).order('id', { ascending: false }).range(offset, offset + limit - 1);
  if (characterId) query = query.eq('character_id', characterId);
  const { data, count, error } = await query;
  if (error || count === null) throw new Error('Deed history lookup failed');
  const items = z.array(deedRowSchema).parse(data).map((d) => ({
    id: d.id, characterId: d.character_id, content: d.content, category: d.category, praise: d.praise,
    earnedXp: d.earned_xp, earnedCategoryPoints: d.earned_category_points, recoveredHp: d.recovered_hp, createdAt: d.created_at,
  }));
  return { items, totalCount: count, limit, offset, hasMore: offset + items.length < count };
}
