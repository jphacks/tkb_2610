import { z } from 'zod';
import { supabase } from '../lib/supabase.js';
import { callRpc } from '../lib/rpc.js';
import { ApiError } from '../lib/api-error.js';

const configurationSchema = z.object({
  daily_xp_limit: z.number().int().positive(), xp_per_deed: z.number().int().positive(),
  hp_recovery: z.number().int().positive(), hp_loss_per_day: z.number().int().positive(),
  first_evolution_xp: z.number().int().positive(), second_evolution_xp: z.number().int().positive(),
  level_xp_step: z.number().int().positive(),
});
export async function getGameConfig() {
  const { data, error } = await supabase.from('game_config').select('*').eq('singleton', true).single();
  if (error) throw new ApiError(500, 'INTERNAL_ERROR', 'ゲーム設定を取得できませんでした。');
  const c = configurationSchema.parse(data);
  return {
    dailyXpLimit: c.daily_xp_limit, xpPerDeed: c.xp_per_deed, hpRecovery: c.hp_recovery,
    hpLossPerDay: c.hp_loss_per_day, firstEvolutionXp: c.first_evolution_xp,
    secondEvolutionXp: c.second_evolution_xp, levelXpStep: c.level_xp_step,
  };
}
export async function settleCharacterState(userId: string): Promise<void> {
  await callRpc('settle_character_state', { p_user_id: userId });
}
export async function createNextCharacter(userId: string, characterId: string) {
  return callRpc('create_next_character', { p_user_id: userId, p_character_id: characterId });
}
export async function getCharacterHistory(userId: string, limit: number, offset: number) {
  return callRpc('get_character_history', { p_user_id: userId, p_limit: limit, p_offset: offset });
}
export async function deleteGuestAccount(userId: string): Promise<void> {
  await callRpc('delete_guest_account', { p_user_id: userId });
}

export async function getCurrentStreakDays(userId: string): Promise<number> {
  return z.number().int().nonnegative().parse(await callRpc('get_current_streak_days', { p_user_id: userId }));
}
