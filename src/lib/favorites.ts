/**
 * «محفوظاتي» — favourites stored on the device (AsyncStorage key FAVORITES_KEY). Pure TS.
 * Keys are stable across content updates (ARCHITECTURE §3):
 *   name   → id
 *   verse  → {nameId, s, a}   (surah + ayah, not the display index which is renumbered)
 *   sunnah → {id, fp, easy, stateId?}   (identity = fp; id may change between versions, re-resolve by fp;
 *            stateId is only a lookup hint — pass it to getSunnahItem/useSunnahItem as `stateHint`)
 * Newest first. The React provider lives in src/hooks/use-favorites.tsx.
 */

export const FAVORITES_KEY = "ilm.favorites.v1";

export interface VerseFav {
  nameId: number;
  s: number;
  a: number;
}

export interface SunnahFav {
  id: string;
  fp: string;
  easy: string;
  /**
   * The item's state when it was saved (SunnahItem.stateId). A hint only: «بمعناها» members are not in the
   * sunan index, so without it opening a saved member means reading chunks until it is found.
   */
  stateId?: number;
}

export interface Favorites {
  names: number[];
  verses: VerseFav[];
  sunan: SunnahFav[];
}

export type FavoriteRef =
  | { kind: "name"; id: number }
  | ({ kind: "verse" } & VerseFav)
  | ({ kind: "sunnah" } & SunnahFav);

export const EMPTY_FAVORITES: Favorites = { names: [], verses: [], sunan: [] };

const sameVerse = (x: VerseFav, y: VerseFav) => x.nameId === y.nameId && x.s === y.s && x.a === y.a;
const posInt = (v: unknown): v is number => typeof v === "number" && Number.isInteger(v) && v > 0;

/** The stored form of a saved sunnah (drops an invalid stateId). */
function sunnahFav(id: string, fp: string, easy: string, stateId?: unknown): SunnahFav {
  return posInt(stateId) ? { id, fp, easy, stateId } : { id, fp, easy };
}

/** A sunnah is identified by its fingerprint; items without fp (should not happen) fall back to id. */
const sameSunnah = (x: { id: string; fp: string }, y: { id: string; fp: string }) =>
  x.fp || y.fp ? x.fp === y.fp : x.id === y.id;

export function isSaved(f: Favorites, ref: FavoriteRef): boolean {
  switch (ref.kind) {
    case "name":
      return f.names.includes(ref.id);
    case "verse":
      return f.verses.some((v) => sameVerse(v, ref));
    case "sunnah":
      return f.sunan.some((x) => sameSunnah(x, ref));
  }
}

/** Adds (at the front) or removes the item. Returns a new object. */
export function toggleFavorite(f: Favorites, ref: FavoriteRef): Favorites {
  const saved = isSaved(f, ref);
  switch (ref.kind) {
    case "name":
      return { ...f, names: saved ? f.names.filter((id) => id !== ref.id) : [ref.id, ...f.names] };
    case "verse": {
      const v: VerseFav = { nameId: ref.nameId, s: ref.s, a: ref.a };
      return { ...f, verses: saved ? f.verses.filter((x) => !sameVerse(x, v)) : [v, ...f.verses] };
    }
    case "sunnah": {
      const x = sunnahFav(ref.id, ref.fp, ref.easy, ref.stateId);
      return { ...f, sunan: saved ? f.sunan.filter((y) => !sameSunnah(y, x)) : [x, ...f.sunan] };
    }
  }
}

/**
 * After a content update a saved sunnah may have a new id / state (resolved by fp). Keep the saved entry
 * in sync so links stay fast: call it with the resolved item. Returns the same object when nothing changes.
 * `stateId` omitted keeps the stored hint.
 */
export function refreshSunnah(f: Favorites, fp: string, id: string, easy: string, stateId?: number): Favorites {
  let changed = false;
  const sunan = f.sunan.map((x) => {
    if (x.fp !== fp) return x;
    const next = sunnahFav(id, fp, easy, posInt(stateId) ? stateId : x.stateId);
    if (next.id === x.id && next.easy === x.easy && next.stateId === x.stateId) return x;
    changed = true;
    return next;
  });
  return changed ? { ...f, sunan } : f;
}

function isObj(v: unknown): v is Record<string, unknown> {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}

/** Accepts anything and returns valid, de-duplicated favourites (first occurrence wins). */
export function sanitizeFavorites(raw: unknown): Favorites {
  const r = isObj(raw) ? raw : {};
  const names: number[] = [];
  for (const id of Array.isArray(r.names) ? r.names : []) if (posInt(id) && !names.includes(id)) names.push(id);
  const verses: VerseFav[] = [];
  for (const v of Array.isArray(r.verses) ? r.verses : []) {
    if (!isObj(v) || !posInt(v.nameId) || !posInt(v.s) || !posInt(v.a)) continue;
    const fav = { nameId: v.nameId, s: v.s, a: v.a };
    if (!verses.some((x) => sameVerse(x, fav))) verses.push(fav);
  }
  const sunan: SunnahFav[] = [];
  for (const x of Array.isArray(r.sunan) ? r.sunan : []) {
    if (!isObj(x) || typeof x.id !== "string" || typeof x.fp !== "string" || (!x.id && !x.fp)) continue;
    const fav = sunnahFav(x.id, x.fp, typeof x.easy === "string" ? x.easy : "", x.stateId);
    if (!sunan.some((y) => sameSunnah(y, fav))) sunan.push(fav);
  }
  return { names, verses, sunan };
}

export function parseStoredFavorites(stored: string | null): Favorites {
  if (!stored) return EMPTY_FAVORITES;
  try {
    return sanitizeFavorites(JSON.parse(stored));
  } catch {
    return EMPTY_FAVORITES;
  }
}

export function favoritesCount(f: Favorites): number {
  return f.names.length + f.verses.length + f.sunan.length;
}
