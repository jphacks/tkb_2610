import type { CharacterLifespanRecord } from "../repositories/character.repository.js";

type CharacterEndDates = Pick<
  CharacterLifespanRecord,
  "status" | "diedAt" | "secondEvolutionDate"
>;

export type NextCharacterAvailability = {
  canCreateNextCharacter: boolean;
  nextCharacterAvailableOn: string | null;
};

const jstDateFormatter = new Intl.DateTimeFormat("en-US", {
  timeZone: "Asia/Tokyo",
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
});

function toJstDate(value: Date): string {
  const parts = jstDateFormatter.formatToParts(value);
  const year = parts.find((part) => part.type === "year")!.value;
  const month = parts.find((part) => part.type === "month")!.value;
  const day = parts.find((part) => part.type === "day")!.value;
  return `${year}-${month}-${day}`;
}

function followingDate(value: string): string {
  const date = new Date(`${value}T00:00:00Z`);
  if (Number.isNaN(date.getTime()) || date.toISOString().slice(0, 10) !== value) {
    throw new Error("Character end date must be a valid YYYY-MM-DD date");
  }
  date.setUTCDate(date.getUTCDate() + 1);
  return date.toISOString().slice(0, 10);
}

export function getNextCharacterAvailability(
  character: CharacterEndDates,
  now: Date = new Date(),
): NextCharacterAvailability {
  let endDate: string;

  if (character.status === "dead") {
    if (!character.diedAt) {
      throw new Error("A dead character must have diedAt");
    }
    endDate = toJstDate(new Date(character.diedAt));
  } else if (character.secondEvolutionDate) {
    endDate = character.secondEvolutionDate;
  } else if (character.status === "retired") {
    throw new Error("A retired character must have secondEvolutionDate");
  } else {
    return {
      canCreateNextCharacter: false,
      nextCharacterAvailableOn: null,
    };
  }

  const nextCharacterAvailableOn = followingDate(endDate);
  return {
    canCreateNextCharacter: toJstDate(now) >= nextCharacterAvailableOn,
    nextCharacterAvailableOn,
  };
}
