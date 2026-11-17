/**
 * Data epoch: a counter bumped whenever a sync switches the active content of a section, so screens
 * re-read their data. Pure TS (module-level state, no react imports). Hooks use
 * `useSyncExternalStore(subscribeEpoch, getDataEpoch)`.
 */
import type { Section } from "./logic";

export interface PacksChange {
  epoch: number;
  sections: Section[];
}

let epoch = 0;
const listeners = new Set<(change: PacksChange) => void>();

export function getDataEpoch(): number {
  return epoch;
}

/** Called after the active version of `sections` changed. Returns the new epoch. */
export function bumpDataEpoch(sections: Section[]): number {
  epoch += 1;
  const change: PacksChange = { epoch, sections: [...sections] };
  for (const cb of [...listeners]) {
    try {
      cb(change);
    } catch {
      // a broken listener must not stop the others
    }
  }
  return epoch;
}

/** Subscribe to content changes; returns an unsubscribe function. */
export function onPacksChanged(cb: (change: PacksChange) => void): () => void {
  listeners.add(cb);
  return () => {
    listeners.delete(cb);
  };
}

/** `useSyncExternalStore`-shaped subscription. */
export function subscribeEpoch(cb: () => void): () => void {
  return onPacksChanged(() => cb());
}

/** Small observable value (used for the sync status shown in «المزيد»). */
export interface Observable<T> {
  get(): T;
  set(next: T): void;
  subscribe(cb: () => void): () => void;
}

export function createObservable<T>(initial: T): Observable<T> {
  let value = initial;
  const subs = new Set<() => void>();
  return {
    get: () => value,
    set(next) {
      value = next;
      for (const cb of [...subs]) cb();
    },
    subscribe(cb) {
      subs.add(cb);
      return () => {
        subs.delete(cb);
      };
    },
  };
}
