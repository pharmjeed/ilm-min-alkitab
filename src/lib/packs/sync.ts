/**
 * Native content sync (ARCHITECTURE §3): runs the pure algorithm in ./sync-core.ts on top of
 * expo-file-system. Call `syncPacks()` after the first render and from «تحقّق من التحديث».
 * Web uses ./sync.web.ts (bundled content only).
 */
import { Directory, File } from "expo-file-system";

import { API_BASE } from "../config";
import { BUNDLED } from "./bundled";
import { bumpDataEpoch } from "./events";
import { hasVersionFiles, loadPointer, savePointer, sectionDir, stagingRoot, versionDir } from "./fs-native";
import type { Section } from "./logic";
import { runSync, type StagingArea, type SyncIO, type SyncResult } from "./sync-core";
import { recordSyncResult, restoreSyncState, syncState } from "./sync-state";

const MANIFEST_TIMEOUT_MS = 15_000;
const FILE_TIMEOUT_MS = 180_000;

async function withTimeout<T>(ms: number, run: (signal: AbortSignal) => Promise<T>): Promise<T> {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), ms);
  try {
    return await run(ctrl.signal);
  } finally {
    clearTimeout(timer);
  }
}

function stage(section: Section, version: string): StagingArea {
  const dir = new Directory(stagingRoot(), `${section}-${version}-${Date.now()}`);
  dir.create({ intermediates: true, idempotent: true });
  const staged: string[] = [];
  return {
    async download(url, file) {
      await withTimeout(FILE_TIMEOUT_MS, (signal) =>
        File.downloadFileAsync(url, new File(dir, file), { idempotent: true, signal }),
      );
      staged.push(file);
    },
    sha256: (file) => new File(dir, file).digest("SHA-256"),
    readText: (file) => new File(dir, file).text(),
    async commit() {
      const target = versionDir(section, version);
      if (target.exists) target.delete(); // a leftover from an interrupted commit
      target.create({ intermediates: true, idempotent: true });
      for (const file of staged) await new File(dir, file).move(new File(target, file), { overwrite: true });
      if (dir.exists) dir.delete();
    },
    async discard() {
      if (dir.exists) dir.delete();
    },
  };
}

const io: SyncIO = {
  async fetchManifest(url) {
    return withTimeout(MANIFEST_TIMEOUT_MS, async (signal) => {
      const res = await fetch(url, { headers: { accept: "application/json" }, signal });
      if (res.status !== 200) return { status: res.status };
      return { status: 200, body: await res.json().catch(() => undefined) };
    });
  },
  readPointer: loadPointer,
  async hasVersion(section, version) {
    return hasVersionFiles(section, version);
  },
  writePointer: savePointer,
  async stage(section, version) {
    return stage(section, version);
  },
  async listVersions(section) {
    const dir = sectionDir(section);
    if (!dir.exists) return [];
    return dir.list().flatMap((x) => (x instanceof Directory ? [x.name] : []));
  },
  async removeVersion(section, version) {
    const dir = versionDir(section, version);
    if (dir.exists) dir.delete();
  },
};

let inFlight: Promise<SyncResult> | null = null;

/** Check the platform for newer content and switch to it when verified. Never throws. */
export function syncPacks(): Promise<SyncResult> {
  if (inFlight) return inFlight;
  inFlight = (async () => {
    await restoreSyncState();
    syncState.set({ ...syncState.get(), running: true });
    let result: SyncResult;
    try {
      // Leftovers of an interrupted run are never needed.
      const staging = stagingRoot();
      if (staging.exists) staging.delete();
      result = await runSync(io, {
        api: API_BASE,
        bundled: { names: BUNDLED.names?.version ?? null, sunan: BUNDLED.sunan?.version ?? null },
      });
    } catch (e) {
      result = {
        status: "error",
        checkedAt: new Date().toISOString(),
        changed: [],
        sections: [],
        error: e instanceof Error ? e.message : String(e),
      };
    }
    if (result.changed.length) bumpDataEpoch(result.changed);
    await recordSyncResult(result);
    return result;
  })().finally(() => {
    inFlight = null;
  });
  return inFlight;
}

/** Downloads are supported on iOS/Android (false on web). */
export const syncSupported = true;

export { syncState, restoreSyncState } from "./sync-state";
export type { SyncState } from "./sync-state";
export type { SyncResult } from "./sync-core";
