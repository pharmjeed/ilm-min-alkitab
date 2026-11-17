/**
 * «اسم اليوم» / «سنّة اليوم» pickers. Pure TS (no react-native imports).
 *
 * nameOfDay() is a faithful copy of the platform's `lib/content/daily.ts` pickNameOfDay() so the app
 * shows the same name as the website on the same (UTC) day. Do not "improve" it.
 * Note: as on the website, mode "fixed" WITHOUT a fixedId falls through to the sequential rule.
 */

export interface NameOfDaySetting {
  mode: "sequential_by_date" | "random_daily" | "fixed";
  fixedId?: number;
}

/** Day number in UTC (the website's `dayNumber`). */
export function utcDay(date: Date = new Date()): number {
  return Math.floor(date.getTime() / 86_400_000);
}

/** Small deterministic PRNG (mulberry32) — identical to the platform's `rng`. */
export function mulberry32(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/** «اسم اليوم»: `names` must be NamesIndex.names (Excel order), exactly the array the website indexes. */
export function nameOfDay<T extends { id: number }>(
  names: readonly T[],
  setting: NameOfDaySetting,
  date: Date = new Date(),
): T | null {
  if (!names.length) return null;
  if (setting.mode === "fixed" && setting.fixedId != null) {
    return names.find((n) => n.id === setting.fixedId) ?? names[0]!;
  }
  const d = utcDay(date);
  if (setting.mode === "random_daily") {
    const r = mulberry32(d * 7919);
    return names[Math.floor(r() * names.length)]!;
  }
  // sequential_by_date (default): cycle through the Excel order, one per day
  return names[d % names.length]!;
}

/** «سنّة اليوم»: `stars[d % stars.length]` from SunanIndex.stars (sheet order). */
export function sunnahOfDay<T>(stars: readonly T[], date: Date = new Date()): T | null {
  if (!stars.length) return null;
  return stars[utcDay(date) % stars.length]!;
}
