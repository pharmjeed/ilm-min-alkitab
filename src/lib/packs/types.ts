/**
 * Content-pack contract shared by the platform (producer) and the «علم من الكتاب» app (consumer).
 *
 * THIS FILE IS COPIED VERBATIM INTO BOTH REPOSITORIES:
 *   platform: lib/app-packs/types.ts
 *   app:      src/lib/packs/types.ts
 * Change it in both places together and bump PACK_SCHEMA on any breaking change.
 *
 * Rules that apply to every text field:
 *  - Quran and hadith text is copied VERBATIM from the source (no trimming of diacritics, no rewording).
 *    The producer may only remove the documented junk: literal "_x000D_"/"_x005F_x000D_" escapes, U+200F,
 *    U+FEFF, and turn U+00A0 into a space. Line breaks are kept.
 *  - Empty / placeholder source values ("'", "'-", "—", "") become `undefined` (key omitted), never "".
 *  - All numbers are plain JSON numbers. Arrays keep the Excel / database order unless stated otherwise.
 *
 * Files of a section live under `<section>/` in a pack set:
 *   names/index.json, names/chunk-01.json …        sunan/index.json, sunan/need-01.json, sunan/need-12-2.json …
 * The app bundles a snapshot of each file renamed to `*.pack` (so Metro treats it as an asset, not source)
 * and later syncs newer files from GET {API}/api/app/v1/manifest and {API}/api/app/v1/packs/<section>/<version>/<file>.
 */

export const PACK_SCHEMA = 1 as const;

/** A file of a section, as listed in the index (chunks) and in the manifest (all files, index first). */
export interface PackFileRef {
  /** Path relative to the section folder, e.g. "index.json", "chunk-03.json", "need-12-2.json". */
  file: string;
  bytes: number;
  /** Lower-case hex sha256 of the exact file bytes (UTF-8 JSON, no BOM, no pretty-printing). */
  sha256: string;
}

/* =====================================================================================
 * Manifest — GET /api/app/v1/manifest (small, short CDN cache)
 * ===================================================================================== */

export interface AppManifest {
  schema: typeof PACK_SCHEMA;
  generatedAt: string; // ISO-8601 UTC
  sections: {
    names?: SectionManifest;
    sunan?: SectionManifest;
  };
}

export interface SectionManifest {
  /**
   * Content version, computed by finalizeSection (lib/app-packs/files.ts): "<section>-" + first 12 hex of
   * sha256 over the index and every chunk serialised with `version: ""` and empty chunk refs.
   * Same content and same source metadata ⇒ same version. Files under a version URL never change.
   */
  version: string;
  publishedAt: string; // ISO-8601 UTC, when this version was uploaded
  /** The oldest app PACK_SCHEMA able to read it (apps with a lower schema ignore the update). */
  schema: typeof PACK_SCHEMA;
  /** Every file of the section; "index.json" is always first. */
  files: PackFileRef[];
  totalBytes: number;
}

/* =====================================================================================
 * NAMES section (source: the platform's published Supabase content, with the platform's display rules
 * already applied by the producer: the «الله» alone-only rule, hidden «تسعة وتسعين» hadiths,
 * renumbered indexes, story hidden when it repeats the verse).
 * ===================================================================================== */

export interface NamesIndex {
  schema: typeof PACK_SCHEMA;
  kind: "names";
  version: string;
  generatedAt: string;
  source: {
    /** "<label>@<published_at>" of the published import, e.g. "v24@2026-09-26T14:27:08Z". */
    content: string;
    /** "<label>@<generated_at>#<sha12>" of the sunnah layer. */
    sunnahLayer?: string;
  };
  stats: { names: number; positions: number; hadiths: number; doors: number; situations: number };
  /** Same setting the website uses for «اسم اليوم» (site_settings.name_of_day). */
  nameOfDay: { mode: "sequential_by_date" | "random_daily" | "fixed"; fixedId?: number };
  /** All names in Excel order (= id order). The website's «اسم اليوم» indexes THIS array. */
  names: NameCard[];
  /** «ماذا تشعر الآن؟» doors in order (16). */
  doors: Door[];
  /** Situations in order: door order, then the situation order inside the door (198). */
  situations: Situation[];
  /** «ما بأنفسهم» second entry: inner types in order, each with its situations (صريح before مشترك). */
  inner: InnerType[];
  /** Markdown pages from site_settings.pages (about / methodology), may be empty strings. */
  pages: { about: string; methodology: string };
  /** Detail chunks. Every name id appears in exactly one chunk. */
  chunks: (PackFileRef & { ids: number[] })[];
}

export interface NameCard {
  id: number;
  name: string;
  compound: boolean;
  /** Short line for lists: meaningExcerpt(summary || when_pray || meaning, 240) as on the website. */
  excerpt: string;
  /** Visible counts after the display rules. */
  positions: number;
  surahs: number;
  hadiths: number;
  /** «الفئة» of the newer forms when the source has it. */
  category?: string;
}

export interface Door {
  id: number; // 1-based, display order
  slug: string; // platform slug (need_tree.slug) — used to map «اسأل عن موقفك» answers
  label: string; // e.g. «ضيقٌ وكرب»
  description: string;
  /** Website copy (lib/feel/copy.ts FEEL_COPY[slug]) when present. */
  lead?: string;
  covers?: string[];
  situationIds: number[];
}

export interface Situation {
  id: number; // 1-based, display order across all doors
  doorId: number;
  slug: string; // platform sub slug
  label: string; // the sub label, e.g. «الكرب الشديد وانسداد المخارج»
  /** The headline shown to the reader, e.g. «أمرٌ أطبق عليك ولا ترى منه مخرجًا». */
  situation: string;
  innerLevel?: string; // «صريح» | «مشترك»
  innerType?: string;
  /**
   * Names for this situation in the website's order (name_situations.ord, hidden-hadith rule applied).
   * verses/hadiths = the number of scoped items actually shown for the pair after ALL display rules
   * (for «الله» this can be lower than the website's list badge). 0 · 0 ⇒ open the full name page.
   */
  names: { id: number; verses: number; hadiths: number }[];
}

export interface InnerType {
  slug: string;
  label: string;
  description: string;
  situations: { id: number; level: string }[]; // situation ids; level «صريح» or «مشترك»
}

/** names/chunk-NN.json */
export interface NamesChunk {
  schema: typeof PACK_SCHEMA;
  kind: "names-chunk";
  version: string;
  names: NameDetail[];
}

export interface NameDetail {
  id: number;
  name: string;
  compound: boolean;
  meaning: string;
  teaches: string;
  whenRecall: string;
  whenPray: string;
  summary: string;
  /** Visible Quran positions, renumbered 1..n in display order. */
  verses: Verse[];
  /** Visible hadith witnesses, renumbered 1..n. */
  hadiths: Hadith[];
  /** «بطاقة الاسم في السنة» when the name has one. */
  sunnah?: { card?: string; teaches?: string; whenRecall?: string; whenPray?: string; duaItems?: string; summary?: string };
  /** Situations this name belongs to, in the website's order, with the scoped evidence. */
  situations: NameInSituation[];
}

export interface Verse {
  i: number; // display index 1..n
  of: number; // n
  s: number; // surah number
  surah: string; // surah name
  a: number; // ayah
  last?: number; // last ayah when the position spans a range
  text: string; // ayah text, verbatim
  prev?: { a: number; text: string };
  next?: { a: number; text: string };
  /** «القصة» — omitted when it only repeats the verse (website rule). */
  context?: string;
  reason?: string; // «سبب ذكر الاسم»
  adds?: string; // «ماذا يضيف هذا الموضع؟»
  draft?: true; // text_status starts with «مسودة»
  dorar?: { id: string; label: string }[]; // «أحاديث تشرح الآية»
}

export interface Hadith {
  i: number;
  of: number;
  text: string; // verbatim
  narrator?: string;
  source?: string;
  ref?: string;
  grade?: string; // صحيح | حسن
  judgment?: string; // حكم المحدث (when it adds to grade)
  url?: string; // dorar link
  nameForm?: string; // how the name appears in the hadith
  scene?: string; // «المشهد»
  reason?: string; // «لماذا جاء الاسم هنا؟»
  adds?: string; // «ماذا يضيف هذا الشاهد؟»
  draft?: true;
}

/** Evidence of one name inside one situation (website page /feel/<door>/<sub>/<id>). */
export interface NameInSituation {
  situationId: number;
  /** Verses in website order (direct first, then by display index); reference Verse.i of this name. */
  verses: ScopedEvidence[];
  /** Hadiths in website order (direct first, then by index); reference Hadith.i of this name. */
  hadiths: ScopedEvidence[];
}

export interface ScopedEvidence {
  i: number; // Verse.i or Hadith.i
  strength: "direct" | "support";
  /** Bold line on the card (need.situation / link.situation), when present. */
  headline?: string;
  /** Bridge sentence (need.note / link.bridge), when present. */
  bridge?: string;
}

/* =====================================================================================
 * SUNAN section (source: the owner's Excel «السنن والأسباب — الملف الشامل مع دليل القارئ»).
 * Hierarchy: domain (12) → need (59) → state (533) → items (9,920). The reader guide shows one
 * representative per «بمعناها» group, in sheet order; members point to their representative.
 * ===================================================================================== */

export type SunanKind = "do" | "avoid"; // «افعل» | «تجنّب (تشخيص)»

/** A highlighted run inside a hadith full text: plain string, or [text, 1 = cause (gold) | 2 = result (green)]. */
export type Seg = string | [string, 1 | 2];

export interface SunanIndex {
  schema: typeof PACK_SCHEMA;
  kind: "sunan";
  version: string;
  generatedAt: string;
  sourceFile: string;
  sourceSha256: string;
  stats: {
    domains: number;
    needs: number;
    states: number;
    items: number;
    guideItems: number; // representatives
    quran: number;
    sunnah: number;
    stars: number;
    macro: number;
    pairs: number;
  };
  domains: SunanDomain[];
  needs: SunanNeed[];
  states: SunanState[];
  /** «ابدأ بهذه» items (representatives), sheet order — used for «سنّة اليوم» without loading chunks. */
  stars: { id: string; fp: string; stateId: number; easy: string }[];
  macro: MacroSunnah[]; // «السنن الكبرى»
  pairs: OpposingPair[]; // «السنن المتقابلة»
  pairNotes: string[];
  methodology: MethodBlock[]; // «المنهج والحدود»
  /** Item chunks: one per need, needs over ~1 MB split at state boundaries ("need-12-2.json"). */
  chunks: (PackFileRef & { needId: number; stateIds: number[] })[];
}

export interface SunanDomain {
  id: number; // 1-based, sheet order
  title: string; // «الرزق والمال»
  needIds: number[];
}

export interface SunanNeed {
  id: number; // 1-based, sheet order
  domainId: number;
  title: string; // «أريد سعة الرزق والبركة والخَلَف»
  kind: SunanKind;
  /** For avoid-needs: the do-need where its remedy lives («المدخل المقابل»). */
  counterpartNeedId?: number;
  stateIds: number[];
  /** Items of OTHER needs that list this need in «مداخل أخرى» (secondary entries). */
  secondaryItemIds: string[];
  counts: { items: number; quran: number; sunnah: number; explicit: number; ijtihad: number; secondary: number };
}

export interface SunanState {
  id: number; // 1-based, sheet order (unique per (need, state) pair; state titles repeat across needs)
  needId: number;
  title: string; // «أريد البركة في طعامي»
  summary?: string; // «الخلاصة» (starts «أبرز الأسباب:»)
  keywords: string[]; // «كلمات البحث», split on «،», trimmed, empties removed
  /** For avoid-states: where the remedy is («العلاج المقابل (الحالة)»). */
  remedy?: { needId: number; stateId?: number };
  /** Representatives in sheet order (the reader guide). Members are reachable via SunnahItem.similar. */
  itemIds: string[];
  /** «بمعناها» members of this state in sheet order (omitted when none) — lets a reader find a member's chunk from the index. */
  memberIds?: string[];
  counts: { items: number; guide: number; stars: number; quran: number; sunnah: number };
  chunk: string; // file name of the chunk holding this state's items
}

/** sunan/need-NN[-p].json */
export interface SunanChunk {
  schema: typeof PACK_SCHEMA;
  kind: "sunan-chunk";
  version: string;
  needId: number;
  stateIds: number[];
  /** Every item (representatives and members) of these states, sheet order. */
  items: SunnahItem[];
}

export interface SunnahItem {
  id: string; // «رقم السنّة» (unique inside a version, NOT stable across versions)
  /** Stable fingerprint across versions: first 12 hex of sha1(norm(ref)|norm(cause)|norm(result)). */
  fp: string;
  stateId: number;
  /** «السنّة بصياغة سهلة» without the «[اجتهاد] » prefix; always contains «←». */
  easy: string;
  cause?: string; // «السبب (ما تفعله أو تتجنبه)»
  result?: string; // «النتيجة»
  explicit: boolean; // «الصراحة» = صريح
  ijtihad?: true; // «اجتهاد»
  ijtihadWhy?: string[]; // «سبب التصنيف», split on «؛ »
  star?: true; // «ابدأ بهذه»
  /** «طريقة التطبيق»: say = «قل:», time = «الوقت:», count = «العدد:» (prefix removed from t). */
  apply?: { k: "say" | "time" | "count"; t: string };
  /** Set on members of a «بمعناها» group: the representative's id. */
  repOf?: string;
  /** Set on representatives with members: member ids in sheet order. */
  similar?: string[];
  /** «مداخل أخرى للسنّة نفسها» resolved to need ids. */
  otherNeedIds?: number[];
  /** «المرجع»: e.g. «سورة البقرة: 261» or «الأحاديث المختارة 9 / 91». */
  ref: string;
  /** Short source label from the reader guide («المصدر»), representatives only. */
  srcLabel?: string;
  /** Quran rows: the verses (verbatim from quran.json) and highlight ranges inside `quran.text`. */
  quran?: {
    s: number; // surah number
    from: number;
    to: number;
    /** Canonical text exactly as in the sheet/quran.json: "ayah (n) ayah (n)…". */
    text: string;
    /** Highlight offsets into `text` (UTF-16 code units, end exclusive): [start, end, 1 | 2]. */
    hl: [number, number, 1 | 2][];
  };
  /** Sunnah rows: «النص كاملاً» with cause/result runs. */
  text?: Seg[];
  grade?: string; // «خلاصة الحكم»: صحيح | حسن
  narrator?: string;
  muhaddith?: string; // «المحدّث»
  takhrij?: string; // «التخريج»
  bab?: string; // «باب الحديث»
  dorar?: string; // dorar hadith code: https://dorar.net/h/<code>
  merged?: number; // «عدد الروايات المدموجة» when > 1
  otherRefs?: string[]; // «روايات أخرى للسنّة نفسها», split on « | »
}

export interface MacroSunnah {
  id: number;
  title: string; // «السنّة الكبرى»
  cause?: string;
  result?: string;
  domain: string;
  /** true for «قانون عام في السنن (لا يخص حاجة بعينها)». */
  general: boolean;
  needIds: number[];
  quranRefs: string[]; // e.g. ["الأعراف 96", "النساء 100"]
  /** Verses verbatim: [surah, ayah, text]. */
  verses: [number, number, string][];
  hadithRefs: string[];
  hadithText?: string;
  note?: string;
}

export interface OpposingPair {
  id: number;
  positive: string;
  positiveRef?: string;
  negative: string;
  negativeRef?: string;
}

export interface MethodBlock {
  t: string; // paragraph text
  h?: true; // heading
}
