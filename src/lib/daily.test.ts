import { describe, expect, it } from "vitest";

import { mulberry32, nameOfDay, sunnahOfDay, utcDay } from "./daily";

const names = Array.from({ length: 194 }, (_, i) => ({ id: i + 1 }));

describe("utcDay", () => {
  it("counts whole UTC days since the epoch", () => {
    expect(utcDay(new Date("1970-01-01T23:59:59Z"))).toBe(0);
    expect(utcDay(new Date("2026-11-17T00:00:00Z"))).toBe(20774);
    expect(utcDay(new Date("2026-11-17T23:59:59Z"))).toBe(20774);
  });
});

describe("nameOfDay (same algorithm as the website)", () => {
  it("sequential_by_date: 2026-11-17 with 194 names → index 16", () => {
    const n = nameOfDay(names, { mode: "sequential_by_date" }, new Date("2026-11-17T10:00:00Z"));
    expect(n).toBe(names[16]);
    expect(n?.id).toBe(17);
  });
  it("advances by one each UTC day", () => {
    const a = nameOfDay(names, { mode: "sequential_by_date" }, new Date("2026-11-18T01:00:00Z"));
    expect(a).toBe(names[17]);
  });
  it("random_daily uses mulberry32 seeded with day*7919", () => {
    const d = utcDay(new Date("2026-11-17T10:00:00Z"));
    const idx = Math.floor(mulberry32(d * 7919)() * names.length);
    expect(nameOfDay(names, { mode: "random_daily" }, new Date("2026-11-17T10:00:00Z"))).toBe(names[idx]);
  });
  it("fixed picks fixedId, or the first name when the id is unknown", () => {
    expect(nameOfDay(names, { mode: "fixed", fixedId: 5 })?.id).toBe(5);
    expect(nameOfDay(names, { mode: "fixed", fixedId: 9999 })?.id).toBe(1);
  });
  it("fixed without fixedId falls through to sequential (website behaviour)", () => {
    const date = new Date("2026-11-17T10:00:00Z");
    expect(nameOfDay(names, { mode: "fixed" }, date)).toBe(names[16]);
  });
  it("returns null for an empty list", () => {
    expect(nameOfDay([], { mode: "sequential_by_date" })).toBeNull();
  });
});

describe("mulberry32", () => {
  it("is deterministic and in [0,1)", () => {
    const a = mulberry32(42);
    const b = mulberry32(42);
    for (let i = 0; i < 5; i++) {
      const x = a();
      expect(x).toBe(b());
      expect(x).toBeGreaterThanOrEqual(0);
      expect(x).toBeLessThan(1);
    }
  });
});

describe("sunnahOfDay", () => {
  it("cycles stars by UTC day", () => {
    const stars = ["a", "b", "c"];
    expect(sunnahOfDay(stars, new Date("2026-11-17T10:00:00Z"))).toBe(stars[20774 % 3]);
    expect(sunnahOfDay([], new Date())).toBeNull();
  });
});
