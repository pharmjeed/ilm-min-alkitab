/**
 * Pack sync algorithm over an injectable IO adapter (pure TS, unit-tested with an in-memory fake;
 * the real adapter is in ./sync.ts on top of expo-file-system).
 *
 *   manifest → for each section: plan → download every file into a staging folder → verify sha256 of
 *   each file and that index.json is the announced version and lists only announced files → move into
 *   packs/<section>/<version>/ → write the pointer atomically (the switch) → delete older versions.
 *
 * Any failure before the pointer write leaves the active content untouched (staging is discarded).
 * A missing (404) manifest is not an error: the feature is simply not deployed yet.
 */
import {
  effectiveSource,
  manifestUrl,
  packFileUrl,
  parseManifest,
  planSection,
  referencedFiles,
  SECTIONS,
  staleVersions,
  withEntry,
  withoutEntry,
  type PackPointer,
  type Section,
} from "./logic";
import { PACK_SCHEMA } from "./types";

export interface StagingArea {
  download(url: string, file: string): Promise<void>;
  /** Lower-case hex SHA-256 of the staged file. */
  sha256(file: string): Promise<string>;
  readText(file: string): Promise<string>;
  /** Move every staged file into packs/<section>/<version>/ (replacing a leftover partial folder). */
  commit(): Promise<void>;
  /** Delete the staging folder (best effort). */
  discard(): Promise<void>;
}

export interface SyncIO {
  /** GET the manifest. `body` is the parsed JSON for status 200 (undefined when not JSON). */
  fetchManifest(url: string): Promise<{ status: number; body?: unknown }>;
  readPointer(): Promise<PackPointer>;
  /** Whether packs/<section>/<version>/index.json exists (the same test the reader uses). */
  hasVersion(section: Section, version: string): Promise<boolean>;
  /** Must be atomic (write a temp file, then rename over the old one). */
  writePointer(pointer: PackPointer): Promise<void>;
  stage(section: Section, version: string): Promise<StagingArea>;
  /** Version folders present under packs/<section>/. */
  listVersions(section: Section): Promise<string[]>;
  removeVersion(section: Section, version: string): Promise<void>;
}

export interface SyncOptions {
  api: string;
  /** Bundled snapshot version per section (null when the app ships none). */
  bundled: Record<Section, string | null>;
  appSchema?: number;
  now?: () => Date;
}

export type SectionResult =
  | "updated" // a new version was downloaded and activated
  | "reverted" // the published version is the bundled one: the download was dropped
  | "current"
  | "absent" // the manifest has no such section
  | "schema" // needs a newer app
  | "failed";

export interface SectionOutcome {
  section: Section;
  result: SectionResult;
  version?: string;
  error?: string;
}

export type SyncStatus = "ok" | "partial" | "not-deployed" | "offline" | "error" | "unsupported";

export interface SyncResult {
  status: SyncStatus;
  checkedAt: string;
  /** Sections whose active content changed (bump the data epoch for these). */
  changed: Section[];
  sections: SectionOutcome[];
  error?: string;
}

const message = (e: unknown) => (e instanceof Error ? e.message : String(e));

async function downloadSection(
  io: SyncIO,
  api: string,
  section: Section,
  version: string,
  files: { file: string; sha256: string }[],
): Promise<void> {
  const staging = await io.stage(section, version);
  try {
    for (const f of files) {
      await staging.download(packFileUrl(api, section, version, f.file), f.file);
      const sha = (await staging.sha256(f.file)).toLowerCase();
      if (sha !== f.sha256) throw new Error(`sha256 mismatch: ${section}/${version}/${f.file}`);
    }
    let index: { kind?: unknown; version?: unknown } | null;
    try {
      index = JSON.parse(await staging.readText("index.json"));
    } catch {
      throw new Error(`index.json of ${section}/${version} is not valid JSON`);
    }
    if (index?.kind !== section || index?.version !== version) {
      throw new Error(`index.json of ${section}/${version} does not match the manifest`);
    }
    const announced = new Set(files.map((f) => f.file));
    const missing = referencedFiles(index).filter((f) => !announced.has(f));
    if (missing.length) throw new Error(`${section}/${version}: index lists files not in the manifest: ${missing.join(", ")}`);
    await staging.commit();
  } catch (e) {
    await staging.discard().catch(() => undefined);
    throw e;
  }
}

async function cleanup(io: SyncIO, section: Section, keep: string | null): Promise<void> {
  try {
    for (const v of staleVersions(await io.listVersions(section), keep)) {
      await io.removeVersion(section, v).catch(() => undefined);
    }
  } catch {
    // best effort
  }
}

export async function runSync(io: SyncIO, opts: SyncOptions): Promise<SyncResult> {
  const now = opts.now ?? (() => new Date());
  const appSchema = opts.appSchema ?? PACK_SCHEMA;
  const checkedAt = now().toISOString();
  const base = { checkedAt, changed: [] as Section[], sections: [] as SectionOutcome[] };

  let res: { status: number; body?: unknown };
  try {
    res = await io.fetchManifest(manifestUrl(opts.api));
  } catch (e) {
    return { ...base, status: "offline", error: message(e) };
  }
  if (res.status === 404) return { ...base, status: "not-deployed" };
  if (res.status !== 200) return { ...base, status: "error", error: `manifest HTTP ${res.status}` };
  const manifest = parseManifest(res.body);
  if (!manifest) return { ...base, status: "error", error: "invalid manifest" };

  let pointer: PackPointer;
  try {
    pointer = await io.readPointer();
  } catch (e) {
    return { ...base, status: "error", error: message(e) };
  }
  // An entry whose folder is gone (restored backup, storage cleanup) is not the content in use — the
  // reader already falls back to the bundled copy. Plan from that, so a version that is still published
  // is downloaded again instead of being taken as "current" forever.
  for (const section of SECTIONS) {
    const entry = pointer.sections[section];
    if (entry && !(await io.hasVersion(section, entry.version).catch(() => true))) pointer = withoutEntry(pointer, section);
  }

  const changed: Section[] = [];
  const sections: SectionOutcome[] = [];
  for (const section of SECTIONS) {
    const bundled = opts.bundled[section];
    const current = effectiveSource(section, pointer, bundled);
    const plan = planSection(manifest.sections[section], current, bundled, appSchema);
    try {
      if (plan.action === "none") {
        sections.push({ section, result: plan.reason, version: current?.version });
        // Housekeeping: drop folders that are not the active download.
        await cleanup(io, section, current?.kind === "downloaded" ? current.version : null);
      } else if (plan.action === "use-bundled") {
        const next = withoutEntry(pointer, section);
        await io.writePointer(next);
        pointer = next;
        changed.push(section);
        sections.push({ section, result: "reverted", version: plan.version });
        await cleanup(io, section, null);
      } else {
        await downloadSection(io, opts.api, section, plan.version, plan.files);
        const next = withEntry(pointer, section, { version: plan.version, bundled, activatedAt: now().toISOString() });
        await io.writePointer(next);
        pointer = next;
        changed.push(section);
        sections.push({ section, result: "updated", version: plan.version });
        await cleanup(io, section, plan.version);
      }
    } catch (e) {
      sections.push({ section, result: "failed", version: current?.version, error: message(e) });
    }
  }

  const failed = sections.filter((s) => s.result === "failed").length;
  const status: SyncStatus = failed === 0 ? "ok" : failed === sections.length ? "error" : "partial";
  return { checkedAt, status, changed, sections, ...(failed ? { error: sections.find((s) => s.error)?.error } : {}) };
}
