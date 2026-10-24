export type JstDayRange = {
  date: string;
  startAt: string;
  endBefore: string;
};

const jstDateFormatter = new Intl.DateTimeFormat("en-US", {
  timeZone: "Asia/Tokyo",
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
});

export function getJstDayRange(now: Date = new Date()): JstDayRange {
  const parts = jstDateFormatter.formatToParts(now);
  const year = parts.find((part) => part.type === "year")!.value;
  const month = parts.find((part) => part.type === "month")!.value;
  const day = parts.find((part) => part.type === "day")!.value;
  const date = `${year}-${month}-${day}`;

  const start = new Date(`${date}T00:00:00+09:00`);
  const end = new Date(start.getTime() + 24 * 60 * 60 * 1000);

  return {
    date,
    startAt: start.toISOString(),
    // 明日0:00ちょうどの投稿は、今日の集計に含めない。
    endBefore: end.toISOString(),
  };
}
