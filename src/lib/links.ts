/**
 * Links that carry lookup hints. Pure TS (type-only import of expo-router).
 *
 * A sunnah item link always carries its fingerprint (`fp`, the identity across content versions) and,
 * when known, its state (`st`): «بمعناها» members are not listed in the sunan index, so the state hint
 * lets s/item/[id] read exactly one chunk instead of searching for it.
 */
import type { Href } from "expo-router";

export interface SunnahLinkTarget {
  id: string;
  fp?: string | null;
  stateId?: number | null;
}

/** Route params of s/item/[id] for an item (sunnah item, star of the index, saved favourite). */
export function sunnahItemParams(item: SunnahLinkTarget): { id: string; fp?: string; st?: string } {
  const params: { id: string; fp?: string; st?: string } = { id: item.id };
  if (item.fp) params.fp = item.fp;
  if (item.stateId != null && Number.isInteger(item.stateId) && item.stateId > 0) params.st = String(item.stateId);
  return params;
}

/** `/s/item/<id>?fp=<fp>&st=<stateId>` — pass to router.push / Card href / Pill href. */
export function sunnahItemHref(item: SunnahLinkTarget): Href {
  return { pathname: "/s/item/[id]", params: sunnahItemParams(item) };
}
