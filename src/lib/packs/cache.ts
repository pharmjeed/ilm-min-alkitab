/**
 * Promise memo cache for parsed pack files. Pure TS.
 * - Concurrent requests for the same key share one load.
 * - Pinned entries (the two indexes) are never evicted; other entries (chunks, up to ~3 MB parsed
 *   each) are kept in LRU order and evicted beyond `maxUnpinned`.
 * - A failed load is forgotten so the next call retries.
 */

export interface MemoCache {
  get<T>(key: string, load: () => Promise<T>, opts?: { pin?: boolean }): Promise<T>;
  /** Already-settled or pending entry without loading. */
  peek<T>(key: string): Promise<T> | undefined;
  /** Remove entries whose key matches (all when no predicate). */
  clear(predicate?: (key: string) => boolean): void;
  keys(): string[];
}

interface Entry {
  promise: Promise<unknown>;
  pinned: boolean;
}

export function createMemoCache(maxUnpinned = 6): MemoCache {
  const map = new Map<string, Entry>();

  const evict = () => {
    let unpinned = 0;
    for (const e of map.values()) if (!e.pinned) unpinned++;
    for (const [k, e] of map) {
      if (unpinned <= maxUnpinned) break;
      if (e.pinned) continue;
      map.delete(k);
      unpinned--;
    }
  };

  return {
    get<T>(key: string, load: () => Promise<T>, opts?: { pin?: boolean }): Promise<T> {
      const hit = map.get(key);
      if (hit) {
        if (!hit.pinned) {
          // refresh LRU position
          map.delete(key);
          map.set(key, hit);
        }
        return hit.promise as Promise<T>;
      }
      const promise = load();
      const entry: Entry = { promise, pinned: !!opts?.pin };
      map.set(key, entry);
      promise.catch(() => {
        if (map.get(key) === entry) map.delete(key);
      });
      evict();
      return promise;
    },
    peek<T>(key: string) {
      return map.get(key)?.promise as Promise<T> | undefined;
    },
    clear(predicate) {
      for (const k of [...map.keys()]) if (!predicate || predicate(k)) map.delete(k);
    },
    keys: () => [...map.keys()],
  };
}
