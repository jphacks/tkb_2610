import type { CharacterLifespanRecord } from "../repositories/character.repository.js";

const millisecondsPerDay = 24 * 60 * 60 * 1000;
const jstDateFormatter = new Intl.DateTimeFormat("en-US", {
  timeZone: "Asia/Tokyo",
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
});

function toJstDayNumber(value: string | Date): number {
  const date = typeof value === "string" ? new Date(value) : value;
  const parts = jstDateFormatter.formatToParts(date);
  const year = Number(parts.find((part) => part.type === "year")!.value);
  const month = Number(parts.find((part) => part.type === "month")!.value);
  const day = Number(parts.find((part) => part.type === "day")!.value);

  // 時刻を除き、日本時間の日付同士を比較できる数値にする。
  return Date.UTC(year, month - 1, day) / millisecondsPerDay;
}

export function calculateCharacterLifespan(
  character: CharacterLifespanRecord,
  now: Date = new Date(),
): number {
  const firstDay = toJstDayNumber(character.createdAt);
  let lastDay = toJstDayNumber(now);

  if (character.status === "dead") {
    if (!character.diedAt) {
      throw new Error("A dead character must have diedAt");
    }
    lastDay = toJstDayNumber(character.diedAt);
  } else if (character.secondEvolutionDate) {
    // 育成終了の処理が遅れても、達成日より後の日付は数えない。
    lastDay = Math.min(lastDay, toJstDayNumber(character.secondEvolutionDate));
  } else if (character.status === "retired") {
    throw new Error("A retired character must have secondEvolutionDate");
  }

  const lifespan = lastDay - firstDay + 1;
  if (lifespan < 1) {
    throw new Error("Character lifespan must be at least one day");
  }

  return lifespan;
}
