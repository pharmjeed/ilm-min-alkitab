/**
 * Simple client-side search over short Arabic texts (names, situations, needs, states, keywords).
 * Pure TS. Matching is on `normalize()`d text (same rules as the website), token by token:
 * every query token must occur somewhere in the item's text.
 */
import { normalize } from "./normalize";

/** Punctuation that should not block a match (quotes, brackets, Arabic comma/semicolon, ornate parens). */
const PUNCT = /[«»"'“”‘’()[\]{}﴿﴾،؛؟?!.,:;\-–—_/\\|*]+/g;

/** Normalised search key of a text: normalize() + punctuation turned into spaces. */
export function searchKey(text: string | null | undefined): string {
  return normalize((text ?? "").replace(PUNCT, " "));
}

/** Query tokens (normalised, punctuation removed). An empty query has no tokens. */
export function queryTokens(query: string | null | undefined): string[] {
  const k = searchKey(query);
  return k ? k.split(" ") : [];
}

/** True when every token occurs in `key` (a searchKey). No tokens ⇒ true. */
export function keyMatches(key: string, tokens: readonly string[]): boolean {
  for (const t of tokens) if (!key.includes(t)) return false;
  return true;
}

/** Convenience: does `text` match `query`? (Builds the key every call — use buildSearchIndex for lists.) */
export function matchesQuery(text: string | readonly string[], query: string): boolean {
  const key = searchKey(Array.isArray(text) ? text.join(" ") : (text as string));
  return keyMatches(key, queryTokens(query));
}

export interface SearchEntry<T> {
  item: T;
  key: string;
  /** Normalised primary text (title) — used to rank exact / prefix matches first. */
  primary: string;
}

/**
 * Pre-compute keys once for a list, then filter many times while the user types.
 * `getText` returns the primary text first, then any secondary texts (summary, keywords…).
 */
export function buildSearchIndex<T>(items: readonly T[], getText: (item: T) => (string | null | undefined)[]): SearchEntry<T>[] {
  return items.map((item) => {
    const texts = getText(item);
    return { item, key: searchKey(texts.filter(Boolean).join(" ")), primary: searchKey(texts[0]) };
  });
}

/**
 * Items matching the query, ranked: primary text equals the query, then primary starts with it,
 * then primary contains every token, then any other match. Ties keep the original (Excel) order.
 * An empty query returns every item in order.
 */
export function searchIndex<T>(index: readonly SearchEntry<T>[], query: string, limit = Infinity): T[] {
  const tokens = queryTokens(query);
  if (!tokens.length) return index.slice(0, limit).map((e) => e.item);
  const q = tokens.join(" ");
  const buckets: T[][] = [[], [], [], []];
  for (const e of index) {
    if (!keyMatches(e.key, tokens)) continue;
    const rank = e.primary === q ? 0 : e.primary.startsWith(q) ? 1 : keyMatches(e.primary, tokens) ? 2 : 3;
    buckets[rank]!.push(e.item);
  }
  return buckets.flat().slice(0, limit);
}
