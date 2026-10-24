import { supabase } from "../lib/supabase.js";
import { z } from "zod";

export type CharacterLifespanRecord = {
  status: "alive" | "dead" | "retired";
  createdAt: string;
  diedAt: string | null;
  endedAt: string | null;
  secondEvolutionDate: string | null;
};

const storedCategoryPointsSchema = z.object({
  kindness: z.number().int().nonnegative(),
  environment: z.number().int().nonnegative(),
  gratitude: z.number().int().nonnegative(),
  courage: z.number().int().nonnegative(),
  cooperation: z.number().int().nonnegative(),
  honesty: z.number().int().nonnegative(),
  self_care: z.number().int().nonnegative(),
});

export type CurrentCharacterRecord = CharacterLifespanRecord & {
  id: string;
  generation: number;
  imageId: string;
  hp: number;
  maxHp: number;
  totalXp: number;
  level: number;
  evolutionStage: number;
  firstEvolutionCategory: string | null;
  secondEvolutionCategory: string | null;
  categoryPoints: {
    kindness: number;
    environment: number;
    gratitude: number;
    courage: number;
    cooperation: number;
    honesty: number;
    selfCare: number;
  };
};

export async function findCurrentCharacterByUserId(
  userId: string,
): Promise<CurrentCharacterRecord | null> {
  const { data, error } = await supabase
    .from("characters")
    .select("id, generation, image_id, hp, max_hp, total_xp, level, evolution_stage, first_evolution_category, second_evolution_category, category_points, status, created_at, died_at, ended_at, second_evolution_date")
    .eq("user_id", userId)
    .order("generation", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (error) {
    throw new Error(`Current character lookup failed: ${error.message}`);
  }

  if (!data) {
    return null;
  }

  const points = storedCategoryPointsSchema.parse(data.category_points);

  return {
    id: data.id,
    generation: data.generation,
    imageId: data.image_id,
    hp: data.hp,
    maxHp: data.max_hp,
    totalXp: data.total_xp,
    level: data.level,
    evolutionStage: data.evolution_stage,
    firstEvolutionCategory: data.first_evolution_category,
    secondEvolutionCategory: data.second_evolution_category,
    categoryPoints: {
      kindness: points.kindness,
      environment: points.environment,
      gratitude: points.gratitude,
      courage: points.courage,
      cooperation: points.cooperation,
      honesty: points.honesty,
      selfCare: points.self_care,
    },
    status: data.status,
    createdAt: data.created_at,
    diedAt: data.died_at,
    endedAt: data.ended_at,
    secondEvolutionDate: data.second_evolution_date,
  };
}

export async function findCharacterLifespansByUserId(
  userId: string,
): Promise<CharacterLifespanRecord[]> {
  const records: CharacterLifespanRecord[] = [];
  const pageSize = 100;

  // DBの一度の取得件数制限で、古い世代が抜けないように分けて読む。
  for (let offset = 0; ; offset += pageSize) {
    const { data, error } = await supabase
      .from("characters")
      .select("status, created_at, died_at, ended_at, second_evolution_date")
      .eq("user_id", userId)
      .order("generation", { ascending: true })
      .range(offset, offset + pageSize - 1);

    if (error) {
      throw new Error(`Character lifespan lookup failed: ${error.message}`);
    }

    records.push(...data.map((character) => ({
      status: character.status,
      createdAt: character.created_at,
      diedAt: character.died_at,
      endedAt: character.ended_at,
      secondEvolutionDate: character.second_evolution_date,
    })));

    if (data.length < pageSize) {
      return records;
    }
  }
}
