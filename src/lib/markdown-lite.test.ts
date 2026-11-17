import { describe, expect, it } from "vitest";

import { parseBlocks, parseInline, stripInline } from "./markdown-lite";

describe("parseInline", () => {
  it("splits bold runs and keeps line breaks", () => {
    expect(parseInline("قبل **عريض** بعد\nسطر")).toEqual([
      { text: "قبل ", bold: false },
      { text: "عريض", bold: true },
      { text: " بعد\nسطر", bold: false },
    ]);
  });
  it("keeps an unmatched ** as text", () => {
    expect(parseInline("a **b")).toEqual([{ text: "a **b", bold: false }]);
  });
  it("handles empty input and empty bold", () => {
    expect(parseInline("")).toEqual([]);
    expect(parseInline(undefined)).toEqual([]);
    expect(parseInline("****x")).toEqual([{ text: "x", bold: false }]);
  });
  it("stripInline removes markers", () => {
    expect(stripInline("**الله** اسم")).toBe("الله اسم");
  });
});

describe("parseBlocks", () => {
  it("parses headings, paragraphs and lists", () => {
    const md = "# عنوان\n\nفقرة أولى\nسطر ثانٍ\n\n- بند **أ**\n- بند ب\n\n1. أول\n٢. ثانٍ\n### صغير ###";
    expect(parseBlocks(md)).toEqual([
      { type: "heading", level: 1, runs: [{ text: "عنوان", bold: false }] },
      { type: "paragraph", runs: [{ text: "فقرة أولى\nسطر ثانٍ", bold: false }] },
      {
        type: "list",
        ordered: false,
        items: [
          [
            { text: "بند ", bold: false },
            { text: "أ", bold: true },
          ],
          [{ text: "بند ب", bold: false }],
        ],
      },
      {
        type: "list",
        ordered: true,
        items: [[{ text: "أول", bold: false }], [{ text: "ثانٍ", bold: false }]],
      },
      { type: "heading", level: 3, runs: [{ text: "صغير", bold: false }] },
    ]);
  });
  it("caps heading level at 3 and handles CRLF", () => {
    expect(parseBlocks("##### x\r\ny")).toEqual([
      { type: "heading", level: 3, runs: [{ text: "x", bold: false }] },
      { type: "paragraph", runs: [{ text: "y", bold: false }] },
    ]);
  });
  it("continues a list item with a following plain line", () => {
    expect(parseBlocks("- a\nb")).toEqual([
      { type: "list", ordered: false, items: [[{ text: "a\nb", bold: false }]] },
    ]);
  });
  it("returns no blocks for empty input", () => {
    expect(parseBlocks("")).toEqual([]);
    expect(parseBlocks("\n\n")).toEqual([]);
  });
});
