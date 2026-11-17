/**
 * Data hooks over the pack store. Each returns `{ data, error, loading }` and re-runs when the data
 * epoch changes (a sync activated newer content). While re-loading after an epoch change the previous
 * data stays visible (`loading` is true).
 *
 *   const { data: index, loading, error } = useNamesIndex();
 *   const { data: name } = useNameDetail(id);          // null = no such name
 *   const { data: state } = useStateItems(stateId);    // { state, items } | null
 *   const { data: item } = useSunnahItem(id, fp, st);  // resolved by fp if ids changed; st = state hint
 *                                                      // (route param / SunnahFav.stateId) — pass it when known
 */
import { useEffect, useEffectEvent, useState, useSyncExternalStore } from "react";

import {
  getDataEpoch,
  getNameDetail,
  getNamesIndex,
  getPackSources,
  getStateItems,
  getSunanIndex,
  getSunnahItem,
  subscribeEpoch,
  type StateItems,
} from "@/lib/packs/store";
import type { PackSourceRef, Section } from "@/lib/packs/logic";
import { syncState, type SyncState } from "@/lib/packs/sync";
import type { NameDetail, NamesIndex, SunanIndex, SunnahItem } from "@/lib/packs/types";

export interface DataState<T> {
  data: T | undefined;
  error: Error | null;
  loading: boolean;
}

/** Current data epoch (re-renders when a sync switches content). */
export function useDataEpoch(): number {
  return useSyncExternalStore(subscribeEpoch, getDataEpoch, getDataEpoch);
}

const toError = (e: unknown) => (e instanceof Error ? e : new Error(String(e)));

interface Loaded<T> {
  key: string;
  epoch: number;
  data: T | undefined;
  error: Error | null;
}

/**
 * Runs `load` whenever `key` or the data epoch changes. `key` must encode every argument of `load`
 * (`null` = nothing to load, e.g. a missing route param).
 */
export function usePackData<T>(key: string | null, load: () => Promise<T>): DataState<T> {
  const epoch = useDataEpoch();
  const [loaded, setLoaded] = useState<Loaded<T> | null>(null);
  const run = useEffectEvent(load);

  useEffect(() => {
    if (key == null) return;
    let alive = true;
    run().then(
      (data) => {
        if (alive) setLoaded({ key, epoch, data, error: null });
      },
      (e: unknown) => {
        if (alive) setLoaded({ key, epoch, data: undefined, error: toError(e) });
      },
    );
    return () => {
      alive = false;
    };
  }, [key, epoch]);

  if (key == null) return { data: undefined, error: null, loading: false };
  const sameKey = loaded?.key === key;
  const fresh = sameKey && loaded.epoch === epoch;
  return {
    data: sameKey ? loaded.data : undefined,
    error: fresh ? loaded.error : null,
    loading: !fresh,
  };
}

export function useNamesIndex(): DataState<NamesIndex> {
  return usePackData("names-index", getNamesIndex);
}

export function useNameDetail(id: number | null | undefined): DataState<NameDetail | null> {
  const ok = id != null && Number.isInteger(id);
  return usePackData(ok ? `name:${id}` : null, () => getNameDetail(id as number));
}

export function useSunanIndex(): DataState<SunanIndex> {
  return usePackData("sunan-index", getSunanIndex);
}

export function useStateItems(stateId: number | null | undefined): DataState<StateItems | null> {
  const ok = stateId != null && Number.isInteger(stateId);
  return usePackData(ok ? `state:${stateId}` : null, () => getStateItems(stateId as number));
}

export function useSunnahItem(
  id: string | null | undefined,
  fp?: string | null,
  stateHint?: number | null,
): DataState<SunnahItem | null> {
  return usePackData(id ? `item:${id}|${fp ?? ""}|${stateHint ?? ""}` : null, () =>
    getSunnahItem(id as string, fp, stateHint),
  );
}

/** Versions in use per section (for «المزيد» → content status). */
export function usePackSources(): DataState<Record<Section, PackSourceRef | null>> {
  return usePackData("sources", getPackSources);
}

/** Live sync status: { running, last: SyncResult | null }. Start a check with `syncPacks()` from @/lib/packs/sync. */
export function useSyncState(): SyncState {
  return useSyncExternalStore(syncState.subscribe, syncState.get, syncState.get);
}

/** Parses a route param into a positive integer id (expo-router params are strings or string[]). */
export function paramInt(v: string | string[] | undefined): number | null {
  const s = Array.isArray(v) ? v[0] : v;
  if (!s || !/^\d+$/.test(s)) return null;
  const n = Number(s);
  return n > 0 ? n : null;
}

/** First value of a route param. */
export function paramStr(v: string | string[] | undefined): string | null {
  const s = Array.isArray(v) ? v[0] : v;
  return s ? s : null;
}
