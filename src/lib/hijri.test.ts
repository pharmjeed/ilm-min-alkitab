import { describe, expect, it } from "vitest";

import { dateLines, formatGregorian, formatHijri, hasHijriSupport, type FormatterFactory } from "./hijri";

// Noon UTC keeps the same civil date in every time zone from UTC-11 to UTC+11.
const DAY = new Date("2026-11-17T12:00:00Z");

/** A fake engine that ignores the requested calendar (like an engine without Umm al-Qura). */
const gregorianOnly: FormatterFactory = (_locale, opts) => new Intl.DateTimeFormat("en-u-ca-gregory", opts);
const throwing: FormatterFactory = () => {
  throw new RangeError("no Intl");
};

describe("formatHijri", () => {
  it("formats Umm al-Qura with Western digits", () => {
    const s = formatHijri(DAY);
    expect(s).toBe("7 جمادى الآخرة 1448 هـ");
    expect(s).not.toMatch(/[٠-٩]/);
  });
  it("returns null when the engine does not honour the calendar", () => {
    expect(formatHijri(DAY, gregorianOnly)).toBeNull();
    expect(hasHijriSupport(gregorianOnly)).toBe(false);
    expect(formatHijri(DAY, throwing)).toBeNull();
  });
  it("reports support on a full-ICU engine", () => {
    expect(hasHijriSupport()).toBe(true);
  });
});

describe("formatGregorian", () => {
  it("formats in Arabic with Western digits", () => {
    expect(formatGregorian(DAY)).toBe("17 نوفمبر 2026");
  });
  it("falls back to a manual format", () => {
    expect(formatGregorian(DAY, throwing)).toBe("17 نوفمبر 2026");
  });
});

describe("dateLines", () => {
  it("shows only the Gregorian date when Hijri is unavailable", () => {
    const d = dateLines(DAY, throwing);
    expect(d.hijri).toBeNull();
    expect(d.gregorian).toBe("17 نوفمبر 2026");
    expect(d.weekday).toBe("الثلاثاء");
  });
});
