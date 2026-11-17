import { describe, expect, it } from "vitest";

import {
  EMPTY_FAVORITES,
  favoritesCount,
  isSaved,
  parseStoredFavorites,
  refreshSunnah,
  sanitizeFavorites,
  toggleFavorite,
} from "./favorites";
import { DEFAULT_SETTINGS, mergeSettings, parseStoredSettings, resolveScheme, sanitizeSettings } from "./settings";

describe("settings", () => {
  it("defaults and sanitises garbage", () => {
    expect(parseStoredSettings(null)).toEqual(DEFAULT_SETTINGS);
    expect(parseStoredSettings("{oops")).toEqual(DEFAULT_SETTINGS);
    expect(sanitizeSettings({ theme: "blue", textScale: 2, morning: { hour: 25, minute: -1, enabled: "yes" } })).toEqual(
      DEFAULT_SETTINGS,
    );
  });
  it("keeps valid values", () => {
    const s = sanitizeSettings({ theme: "light", textScale: 1.3, morning: { enabled: true, hour: 5, minute: 30 } });
    expect(s).toEqual({ theme: "light", textScale: 1.3, morning: { enabled: true, hour: 5, minute: 30, dismissedPrompt: false } });
  });
  it("merges morning field by field", () => {
    const s = mergeSettings(DEFAULT_SETTINGS, { morning: { hour: 6 } });
    expect(s.morning).toEqual({ enabled: false, hour: 6, minute: 0, dismissedPrompt: false });
    expect(mergeSettings(s, { theme: "dark" }).morning.hour).toBe(6);
  });
  it("resolves the scheme: system follows the device, unknown means dark", () => {
    expect(resolveScheme("system", "light")).toBe("light");
    expect(resolveScheme("system", "dark")).toBe("dark");
    expect(resolveScheme("system", null)).toBe("dark");
    expect(resolveScheme("system", "unspecified")).toBe("dark");
    expect(resolveScheme("light", "dark")).toBe("light");
  });
});

describe("favorites", () => {
  it("toggles names, verses and sunan (newest first)", () => {
    let f = toggleFavorite(EMPTY_FAVORITES, { kind: "name", id: 3 });
    f = toggleFavorite(f, { kind: "name", id: 7 });
    expect(f.names).toEqual([7, 3]);
    f = toggleFavorite(f, { kind: "verse", nameId: 1, s: 2, a: 255 });
    expect(isSaved(f, { kind: "verse", nameId: 1, s: 2, a: 255 })).toBe(true);
    expect(isSaved(f, { kind: "verse", nameId: 1, s: 2, a: 256 })).toBe(false);
    f = toggleFavorite(f, { kind: "sunnah", id: "12", fp: "abc", easy: "إذا … ← …" });
    expect(isSaved(f, { kind: "sunnah", id: "99", fp: "abc", easy: "" })).toBe(true); // identity = fp
    expect(favoritesCount(f)).toBe(4);
    f = toggleFavorite(f, { kind: "name", id: 3 });
    f = toggleFavorite(f, { kind: "verse", nameId: 1, s: 2, a: 255 });
    f = toggleFavorite(f, { kind: "sunnah", id: "13", fp: "abc", easy: "" });
    expect(f).toEqual({ names: [7], verses: [], sunan: [] });
    expect(EMPTY_FAVORITES).toEqual({ names: [], verses: [], sunan: [] }); // not mutated
  });
  it("refreshes a sunnah id after an update", () => {
    const f = toggleFavorite(EMPTY_FAVORITES, { kind: "sunnah", id: "1", fp: "fp1", easy: "a" });
    const g = refreshSunnah(f, "fp1", "5", "b");
    expect(g.sunan).toEqual([{ id: "5", fp: "fp1", easy: "b" }]);
    expect(refreshSunnah(g, "fp1", "5", "b")).toBe(g);
  });
  it("keeps the state hint of a saved sunnah", () => {
    const f = toggleFavorite(EMPTY_FAVORITES, { kind: "sunnah", id: "1", fp: "fp1", easy: "a", stateId: 4 });
    expect(f.sunan).toEqual([{ id: "1", fp: "fp1", easy: "a", stateId: 4 }]);
    const g = refreshSunnah(f, "fp1", "1", "a", 9); // the item moved to another state
    expect(g.sunan[0]?.stateId).toBe(9);
    expect(refreshSunnah(g, "fp1", "2", "a").sunan[0]).toEqual({ id: "2", fp: "fp1", easy: "a", stateId: 9 }); // hint kept
    expect(refreshSunnah(g, "fp1", "1", "a", 9)).toBe(g);
    expect(toggleFavorite(EMPTY_FAVORITES, { kind: "sunnah", id: "1", fp: "x", easy: "", stateId: 0 }).sunan[0]).toEqual({
      id: "1",
      fp: "x",
      easy: "",
    });
  });
  it("sanitises stored data and removes duplicates", () => {
    expect(parseStoredFavorites("nope")).toEqual(EMPTY_FAVORITES);
    expect(
      sanitizeFavorites({
        names: [1, 1, "2", 0, 3.5, 4],
        verses: [{ nameId: 1, s: 2, a: 3 }, { nameId: 1, s: 2, a: 3 }, { nameId: 1, s: 0, a: 3 }],
        sunan: [{ id: "1", fp: "x" }, { id: "2", fp: "x", easy: "e" }, { id: 3, fp: "y" }, { id: "4", fp: "z", easy: "", stateId: 7 }, { id: "5", fp: "w", easy: "", stateId: "7" }],
      }),
    ).toEqual({
      names: [1, 4],
      verses: [{ nameId: 1, s: 2, a: 3 }],
      sunan: [{ id: "1", fp: "x", easy: "" }, { id: "4", fp: "z", easy: "", stateId: 7 }, { id: "5", fp: "w", easy: "" }],
    });
  });
});
