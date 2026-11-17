/**
 * Small sunan pack conforming to src/lib/packs/types.ts — for unit tests only (never bundled).
 * Placeholder texts; real Quran/hadith text only ever comes from the producer's packs.
 */
import type { SunanChunk, SunanIndex, SunnahItem } from "../packs/types";

export const SUNAN_VERSION = "sunan-fixture00001";

const item = (id: string, fp: string, stateId: number, extra: Partial<SunnahItem> = {}): SunnahItem => ({
  id,
  fp,
  stateId,
  easy: `إذا فعلت ${id} ← كان كذا`,
  explicit: true,
  ref: "مرجع تجريبي",
  ...extra,
});

export const sunanChunk1: SunanChunk = {
  schema: 1,
  kind: "sunan-chunk",
  version: SUNAN_VERSION,
  needId: 1,
  stateIds: [1, 2],
  items: [
    item("10", "fp0000000010", 1, { star: true, similar: ["11"], text: ["نص ", ["سبب", 1], " ثم ", ["نتيجة", 2]] }),
    item("11", "fp0000000011", 1, { repOf: "10" }),
    item("12", "fp0000000012", 2, { quran: { s: 2, from: 261, to: 261, text: "آية (261)", hl: [[0, 3, 1]] } }),
  ],
};

export const sunanChunk2: SunanChunk = {
  schema: 1,
  kind: "sunan-chunk",
  version: SUNAN_VERSION,
  needId: 2,
  stateIds: [3],
  items: [item("13", "fp0000000013", 3, { explicit: false, ijtihad: true })],
};

const counts = { items: 0, quran: 0, sunnah: 0, explicit: 0, ijtihad: 0, secondary: 0 };

export const sunanIndex: SunanIndex = {
  schema: 1,
  kind: "sunan",
  version: SUNAN_VERSION,
  generatedAt: "2026-11-17T00:00:00Z",
  sourceFile: "fixture.xlsx",
  sourceSha256: "c".repeat(64),
  stats: { domains: 1, needs: 2, states: 3, items: 4, guideItems: 3, quran: 1, sunnah: 3, stars: 1, macro: 0, pairs: 0 },
  domains: [{ id: 1, title: "الرزق والمال", needIds: [1, 2] }],
  needs: [
    { id: 1, domainId: 1, title: "أريد سعة الرزق", kind: "do", stateIds: [1, 2], secondaryItemIds: [], counts },
    { id: 2, domainId: 1, title: "ما يمحق البركة", kind: "avoid", counterpartNeedId: 1, stateIds: [3], secondaryItemIds: [], counts },
  ],
  states: [
    { id: 1, needId: 1, title: "أريد البركة في طعامي", keywords: ["طعام"], itemIds: ["10"], counts: { items: 2, guide: 1, stars: 1, quran: 0, sunnah: 2 }, chunk: "need-01.json" },
    { id: 2, needId: 1, title: "أريد الخلف", keywords: [], itemIds: ["12"], counts: { items: 1, guide: 1, stars: 0, quran: 1, sunnah: 0 }, chunk: "need-01.json" },
    { id: 3, needId: 2, title: "الإسراف", keywords: [], remedy: { needId: 1, stateId: 1 }, itemIds: ["13"], counts: { items: 1, guide: 1, stars: 0, quran: 0, sunnah: 1 }, chunk: "need-02.json" },
  ],
  stars: [{ id: "10", fp: "fp0000000010", stateId: 1, easy: "إذا فعلت 10 ← كان كذا" }],
  macro: [],
  pairs: [],
  pairNotes: [],
  methodology: [{ t: "المنهج", h: true }, { t: "نص" }],
  chunks: [
    { file: "need-01.json", bytes: 100, sha256: "d".repeat(64), needId: 1, stateIds: [1, 2] },
    { file: "need-02.json", bytes: 100, sha256: "e".repeat(64), needId: 2, stateIds: [3] },
  ],
};
