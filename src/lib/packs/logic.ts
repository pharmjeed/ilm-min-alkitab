/**
 * Pure logic of the pack layer (no react-native / expo imports): sections, URL and file-name rules,
 * manifest validation, the active-version pointer, version selection and sync planning.
 */
import { PACK_SCHEMA, type AppManifest, type PackFileRef, type SectionManifest } from "./types";

export const SECTIONS = ["names", "sunan"] as const;
export type Section = (typeof SECTIONS)[number];

export const isSection = (s: unknown): s is Section => s === "names" || s === "sunan";

/* ---------------------------------------------------------------- names, urls */

/** File names inside a section: "index.json", "chunk-03.json", "need-12-2.json". No paths. */
const SAFE_FILE = /^[a-z0-9][a-z0-9_-]{0,80}\.json$/;
/** Versions are used as directory names: "names-0123456789ab". */
const SAFE_VERSION = /^[a-z0-9][a-z0-9._-]{0,80}$/i;
const SHA256 = /^[0-9a-f]{64}$/;

export const isSafeFileName = (f: unknown): f is string => typeof f === "string" && SAFE_FILE.test(f);
export const isSafeVersion = (v: unknown): v is string =>
  typeof v === "string" && SAFE_VERSION.test(v) && !v.includes("..");
export const isSha256Hex = (s: unknown): s is string => typeof s === "string" && SHA256.test(s);

const trimSlash = (s: string) => s.replace(/\/+$/, "");

export function manifestUrl(api: string): string {
  return `${trimSlash(api)}/api/app/v1/manifest`;
}

export function packFileUrl(api: string, section: Section, version: string, file: string): string {
  return `${trimSlash(api)}/api/app/v1/packs/${section}/${encodeURIComponent(version)}/${encodeURIComponent(file)}`;
}

/** Bundled snapshot file name of a pack file: "chunk-01.json" → "chunk-01.pack". */
export function packAssetName(file: string): string {
  return file.replace(/\.json$/, ".pack");
}

/* ---------------------------------------------------------------- manifest */

function isObj(v: unknown): v is Record<string, unknown> {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}
const isInt = (v: unknown, min = 0): v is number => typeof v === "number" && Number.isInteger(v) && v >= min;

export function parseFileRef(raw: unknown): PackFileRef | null {
  if (!isObj(raw) || !isSafeFileName(raw.file) || !isInt(raw.bytes) || typeof raw.sha256 !== "string") return null;
  const sha256 = raw.sha256.toLowerCase();
  if (!isSha256Hex(sha256)) return null;
  return { file: raw.file, bytes: raw.bytes, sha256 };
}

export function parseSectionManifest(raw: unknown): SectionManifest | null {
  if (!isObj(raw) || !isSafeVersion(raw.version) || !isInt(raw.schema, 1) || !Array.isArray(raw.files)) return null;
  const files: PackFileRef[] = [];
  const seen = new Set<string>();
  for (const f of raw.files) {
    const ref = parseFileRef(f);
    if (!ref || seen.has(ref.file)) return null;
    seen.add(ref.file);
    files.push(ref);
  }
  if (!files.length || files[0]!.file !== "index.json") return null;
  const totalBytes = isInt(raw.totalBytes) ? raw.totalBytes : files.reduce((n, f) => n + f.bytes, 0);
  return {
    version: raw.version,
    publishedAt: typeof raw.publishedAt === "string" ? raw.publishedAt : "",
    schema: raw.schema as typeof PACK_SCHEMA,
    files,
    totalBytes,
  };
}

/** Validates GET /api/app/v1/manifest. A malformed section is dropped (treated as absent). */
export function parseManifest(raw: unknown): AppManifest | null {
  if (!isObj(raw) || !isInt(raw.schema, 1) || !isObj(raw.sections)) return null;
  const sections: AppManifest["sections"] = {};
  for (const s of SECTIONS) {
    const sm = parseSectionManifest(raw.sections[s]);
    if (sm) sections[s] = sm;
  }
  return {
    schema: raw.schema as typeof PACK_SCHEMA,
    generatedAt: typeof raw.generatedAt === "string" ? raw.generatedAt : "",
    sections,
  };
}

/* ---------------------------------------------------------------- pointer (packs/active.json) */

export interface PointerEntry {
  /** The downloaded version that is active. */
  version: string;
  /** The bundled snapshot version at activation time; a different bundled version (app update) wins. */
  bundled: string | null;
  activatedAt: string;
}

export interface PackPointer {
  v: 1;
  sections: Partial<Record<Section, PointerEntry>>;
}

export const EMPTY_POINTER: PackPointer = { v: 1, sections: {} };

export function parsePointer(raw: unknown): PackPointer {
  if (!isObj(raw) || raw.v !== 1 || !isObj(raw.sections)) return EMPTY_POINTER;
  const sections: PackPointer["sections"] = {};
  for (const s of SECTIONS) {
    const e = raw.sections[s];
    if (!isObj(e) || !isSafeVersion(e.version)) continue;
    const bundled = e.bundled === null ? null : isSafeVersion(e.bundled) ? e.bundled : undefined;
    if (bundled === undefined) continue;
    sections[s] = { version: e.version, bundled, activatedAt: typeof e.activatedAt === "string" ? e.activatedAt : "" };
  }
  return { v: 1, sections };
}

export function withEntry(p: PackPointer, section: Section, entry: PointerEntry): PackPointer {
  return { v: 1, sections: { ...p.sections, [section]: entry } };
}

export function withoutEntry(p: PackPointer, section: Section): PackPointer {
  const sections = { ...p.sections };
  delete sections[section];
  return { v: 1, sections };
}

/* ---------------------------------------------------------------- version selection */

export interface PackSourceRef {
  kind: "downloaded" | "bundled";
  version: string;
}

/**
 * Which copy of a section to read: the downloaded version from the pointer, unless the app now ships a
 * different bundled snapshot than the one it was downloaded over (the app was updated) — then bundled.
 */
export function effectiveSource(section: Section, pointer: PackPointer, bundledVersion: string | null): PackSourceRef | null {
  const e = pointer.sections[section];
  if (e && e.bundled === bundledVersion) return { kind: "downloaded", version: e.version };
  return bundledVersion ? { kind: "bundled", version: bundledVersion } : null;
}

export type SectionPlan =
  | { action: "none"; reason: "absent" | "schema" | "current" }
  | { action: "use-bundled"; version: string }
  | { action: "download"; version: string; files: PackFileRef[] };

/** What sync should do for one section given the manifest entry and what is active now. */
export function planSection(
  sm: SectionManifest | undefined,
  current: PackSourceRef | null,
  bundledVersion: string | null,
  appSchema: number = PACK_SCHEMA,
): SectionPlan {
  if (!sm) return { action: "none", reason: "absent" };
  if (sm.schema > appSchema) return { action: "none", reason: "schema" };
  if (current?.version === sm.version) return { action: "none", reason: "current" };
  if (bundledVersion === sm.version) return { action: "use-bundled", version: sm.version };
  return { action: "download", version: sm.version, files: sm.files };
}

/** Downloaded version folders that can be deleted. */
export function staleVersions(existing: readonly string[], keep: string | null): string[] {
  return existing.filter((v) => v !== keep).sort();
}

/** Every chunk file an index refers to (names: chunks[].file, sunan: chunks[].file). */
export function referencedFiles(index: unknown): string[] {
  if (!isObj(index) || !Array.isArray(index.chunks)) return [];
  return index.chunks.flatMap((c) => (isObj(c) && typeof c.file === "string" ? [c.file] : []));
}
