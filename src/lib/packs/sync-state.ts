/**
 * Sync status shared by the native and web sync modules (shown in «المزيد» → content status).
 * The last result is persisted so «آخر تحقّق» survives restarts.
 */
import AsyncStorage from "@react-native-async-storage/async-storage";

import { createObservable } from "./events";
import type { SyncResult } from "./sync-core";

export const SYNC_KEY = "ilm.sync.v1";

export interface SyncState {
  running: boolean;
  last: SyncResult | null;
}

export const syncState = createObservable<SyncState>({ running: false, last: null });

let restored = false;

/** Load the persisted last result once (no-op afterwards). */
export async function restoreSyncState(): Promise<void> {
  if (restored) return;
  restored = true;
  try {
    const raw = await AsyncStorage.getItem(SYNC_KEY);
    const last = raw ? (JSON.parse(raw) as SyncResult) : null;
    if (last && typeof last.checkedAt === "string" && !syncState.get().last) {
      syncState.set({ ...syncState.get(), last });
    }
  } catch {
    // ignore: status is informational
  }
}

export async function recordSyncResult(result: SyncResult): Promise<void> {
  syncState.set({ running: false, last: result });
  try {
    await AsyncStorage.setItem(SYNC_KEY, JSON.stringify(result));
  } catch {
    // ignore
  }
}
