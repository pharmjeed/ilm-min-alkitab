import { describe, expect, it } from "vitest";

import { HADITHS, NAMES, POSITIONS, SITUATIONS, VERSES, WITNESSES, arabicCount, supportLabel } from "./count";

describe("arabicCount (port of the platform's lib/arabic/count.ts)", () => {
  it("uses singular, dual, few and many forms", () => {
    expect(arabicCount(1, POSITIONS)).toBe("موضع واحد");
    expect(arabicCount(2, POSITIONS)).toBe("موضعان");
    expect(arabicCount(5, POSITIONS)).toBe("5 مواضع");
    expect(arabicCount(10, VERSES)).toBe("10 آيات");
    expect(arabicCount(11, HADITHS)).toBe("11 حديثًا");
    expect(arabicCount(1362, POSITIONS)).toBe("1,362 موضعًا");
    expect(arabicCount(0, NAMES)).toBe("0 أسماء");
    expect(arabicCount(2, SITUATIONS)).toBe("حالتان");
    expect(arabicCount(3, WITNESSES)).toBe("3 شواهد");
  });
});

describe("supportLabel", () => {
  it("hides zero parts", () => {
    expect(supportLabel(3, 2)).toBe("3 آيات · حديثان");
    expect(supportLabel(0, 1)).toBe("حديث واحد");
    expect(supportLabel(0, 0)).toBe("");
  });
});
