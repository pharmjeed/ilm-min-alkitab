import { describe, expect, it } from "vitest";

import { buildSearchIndex, keyMatches, matchesQuery, queryTokens, searchIndex, searchKey } from "./search";

describe("searchKey / queryTokens", () => {
  it("normalises and strips punctuation", () => {
    expect(searchKey("«الرَّحْمَنُ»، الرحيم!")).toBe("الرحمن الرحيم");
    expect(queryTokens("  أريدُ   البركة ")).toEqual(["اريد", "البركه"]);
    expect(queryTokens("")).toEqual([]);
    expect(queryTokens("«»")).toEqual([]);
  });
});

describe("matching", () => {
  it("requires every token, ignoring diacritics and hamza forms", () => {
    expect(matchesQuery("أريد البركة في طعامي", "البركه طعام")).toBe(true);
    expect(matchesQuery("أريد البركة في طعامي", "البركه مال")).toBe(false);
    expect(matchesQuery(["الرزق والمال", "سعة الرزق"], "سعه")).toBe(true);
    expect(keyMatches("abc", [])).toBe(true);
  });
});

describe("searchIndex", () => {
  const items = [
    { id: 1, title: "الرحيم", summary: "" },
    { id: 2, title: "الرحمن", summary: "اسم فيه الرحمة الواسعة" },
    { id: 3, title: "الغفور", summary: "يغفر برحمته" },
    { id: 4, title: "رحمن الدنيا", summary: "" },
  ];
  const index = buildSearchIndex(items, (i) => [i.title, i.summary]);

  it("returns everything in order for an empty query", () => {
    expect(searchIndex(index, "").map((i) => i.id)).toEqual([1, 2, 3, 4]);
  });
  it("ranks exact, then prefix, then title, then other matches", () => {
    expect(searchIndex(index, "الرحمن").map((i) => i.id)).toEqual([2]);
    expect(searchIndex(index, "رحم").map((i) => i.id)).toEqual([4, 2, 3]); // «الرحيم» has no «رحم» run
  });
  it("respects the limit", () => {
    expect(searchIndex(index, "رحم", 2).map((i) => i.id)).toEqual([4, 2]);
  });
});
