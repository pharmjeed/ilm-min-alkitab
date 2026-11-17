/**
 * Web: no downloads — the web build always shows its bundled snapshot (ARCHITECTURE §3).
 * Same API as ./sync.ts.
 */
import type { SyncResult } from "./sync-core";
import { recordSyncResult, restoreSyncState } from "./sync-state";

export function syncPacks(): Promise<SyncResult> {
  const result: SyncResult = { status: "unsupported", checkedAt: new Date().toISOString(), changed: [], sections: [] };
  return restoreSyncState()
    .then(() => recordSyncResult(result))
    .then(() => result);
}

export const syncSupported = false;

export { syncState, restoreSyncState } from "./sync-state";
export type { SyncState } from "./sync-state";
export type { SyncResult } from "./sync-core";
