/**
 * Small names pack conforming to src/lib/packs/types.ts — for unit tests only (never bundled).
 * The texts are short placeholders; real Quran/hadith text only ever comes from the producer's packs.
 */
import type { NamesChunk, NamesIndex } from "../packs/types";

export const NAMES_VERSION = "names-fixture00001";

export const namesChunk1: NamesChunk = {
  schema: 1,
  kind: "names-chunk",
  version: NAMES_VERSION,
  names: [
    {
      id: 1,
      name: "الله",
      compound: false,
      meaning: "**الاسم الجامع** لصفات الكمال.",
      teaches: "يعلّمني التوحيد.",
      whenRecall: "في كل حال.",
      whenPray: "في كل دعاء.",
      summary: "الاسم الأعظم.",
      verses: [{ i: 1, of: 1, s: 1, surah: "الفاتحة", a: 1, text: "نص تجريبي" }],
      hadiths: [],
      situations: [{ situationId: 1, verses: [{ i: 1, strength: "direct", headline: "عنوان" }], hadiths: [] }],
    },
  ],
};

export const namesChunk2: NamesChunk = {
  schema: 1,
  kind: "names-chunk",
  version: NAMES_VERSION,
  names: [2, 3].map((id) => ({
    id,
    name: id === 2 ? "الرحمن" : "الرحيم",
    compound: false,
    meaning: "معنى",
    teaches: "",
    whenRecall: "",
    whenPray: "",
    summary: "",
    verses: [],
    hadiths: [{ i: 1, of: 1, text: "نص تجريبي", grade: "صحيح" }],
    situations: [],
  })),
};

export const namesIndex: NamesIndex = {
  schema: 1,
  kind: "names",
  version: NAMES_VERSION,
  generatedAt: "2026-11-17T00:00:00Z",
  source: { content: "fixture" },
  stats: { names: 3, positions: 1, hadiths: 2, doors: 1, situations: 2 },
  nameOfDay: { mode: "sequential_by_date" },
  names: [
    { id: 1, name: "الله", compound: false, excerpt: "الاسم الجامع", positions: 1, surahs: 1, hadiths: 0 },
    { id: 2, name: "الرحمن", compound: false, excerpt: "معنى", positions: 0, surahs: 0, hadiths: 1 },
    { id: 3, name: "الرحيم", compound: false, excerpt: "معنى", positions: 0, surahs: 0, hadiths: 1, category: "فئة" },
  ],
  doors: [{ id: 1, slug: "door-1", label: "ضيقٌ وكرب", description: "وصف", situationIds: [1, 2] }],
  situations: [
    { id: 1, doorId: 1, slug: "sub-1", label: "الكرب", situation: "أمرٌ أطبق عليك", innerLevel: "صريح", names: [{ id: 1, verses: 1, hadiths: 0 }] },
    { id: 2, doorId: 1, slug: "sub-2", label: "الهمّ", situation: "همٌّ لا يزول", names: [{ id: 2, verses: 0, hadiths: 1 }] },
  ],
  inner: [{ slug: "fear", label: "الخوف", description: "وصف", situations: [{ id: 1, level: "صريح" }] }],
  pages: { about: "# عن\n\nنص", methodology: "" },
  chunks: [
    { file: "chunk-01.json", bytes: 100, sha256: "a".repeat(64), ids: [1] },
    { file: "chunk-02.json", bytes: 100, sha256: "b".repeat(64), ids: [2, 3] },
  ],
};
