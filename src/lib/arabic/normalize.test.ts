import { describe, expect, it } from "vitest";
import { normalize, pyStrip, pySplit, pyIntFloat, pyLstrip, collapseWs } from "./normalize";

describe("normalize (must match scripts/excel_to_json.py)", () => {
  it("removes tashkeel and tatweel", () => {
    expect(normalize("الرَّحْمَـٰنِ الرَّحِيمِ")).toBe("الرحمن الرحيم");
    expect(normalize("بِسْمِ اللَّهِ")).toBe("بسم الله");
    expect(normalize("الـــلــه")).toBe("الله");
  });
  it("unifies hamza forms, alef maqsura, ta marbuta", () => {
    expect(normalize("إبراهيم أحمد آمن ٱلله")).toBe("ابراهيم احمد امن الله");
    expect(normalize("الأنعام")).toBe("الانعام");
    expect(normalize("موسى")).toBe("موسي");
    expect(normalize("رحمة")).toBe("رحمه");
    expect(normalize("مؤمن سائل")).toBe("مومن سايل");
  });
  it("collapses whitespace and trims", () => {
    expect(normalize("  الله   ربّ   العالمين \n")).toBe("الله رب العالمين");
    expect(normalize(null)).toBe("");
    expect(normalize(undefined)).toBe("");
  });
});

describe("python-compatible helpers", () => {
  it("pyStrip strips NBSP and ascii whitespace like str.strip()", () => {
    expect(pyStrip("  abc \t\n")).toBe("abc");
    expect(pyStrip("﻿abc")).toBe("﻿abc"); // Python does not treat BOM as whitespace
  });
  it("pySplit behaves like str.split()", () => {
    expect(pySplit("  a  b\tc\n")).toEqual(["a", "b", "c"]);
    expect(pySplit("   ")).toEqual([]);
  });
  it("pyIntFloat behaves like int(float(x))", () => {
    expect(pyIntFloat("12")).toBe(12);
    expect(pyIntFloat("12.0")).toBe(12);
    expect(pyIntFloat(" 7 ")).toBe(7);
    expect(pyIntFloat("٥")).toBe(5);
    expect(pyIntFloat("")).toBeNull();
    expect(pyIntFloat("abc")).toBeNull();
  });
  it("pyLstrip strips any of the given chars", () => {
    expect(pyLstrip("الله", "ال")).toBe("ه");
    expect(pyLstrip("العزيز", "ال")).toBe("عزيز");
    expect(pyLstrip("رحمن", "ال")).toBe("رحمن");
  });
  it("collapseWs", () => {
    expect(collapseWs("a  \n b")).toBe("a b");
  });
});
