/**
 * Content store over an injectable pack source. Pure TS so it is unit-tested in Node; the app wires it to
 * the real readers in ./store.ts.
 *
 * Only the two indexes are read eagerly; chunks are loaded lazily and memoised (LRU) per
 * (section, version, file). Sunnah items are located through a per-version id/fp → chunk map.
 */
import { createMemoCache, type MemoCache } from "./cache";
import type { PackSourceRef, Section } from "./logic";
import type { NameDetail, NamesChunk, NamesIndex, SunanChunk, SunanIndex, SunanState, SunnahItem } from "./types";

export interface PackSource {
  /** Which copy of the section to read now (downloaded or bundled), or null when there is none. */
  resolve(section: Section): Promise<PackSourceRef | null>;
  /** The exact text of `file` (e.g. "index.json", "chunk-03.json") of that copy. */
  readText(section: Section, source: PackSourceRef, file: string): Promise<string>;
}

export type PackErrorCode = "unavailable" | "invalid";

export class PackError extends Error {
  readonly code: PackErrorCode;
  constructor(code: PackErrorCode, message: string) {
    super(message);
    this.name = "PackError";
    this.code = code;
  }
}

export interface StateItems {
  state: SunanState;
  /** Every item of the state (representatives and «بمعناها» members), sheet order. */
  items: SunnahItem[];
}

export interface PackStore {
  getNamesIndex(): Promise<NamesIndex>;
  /** null when the id is not in the current names index. */
  getNameDetail(id: number): Promise<NameDetail | null>;
  getSunanIndex(): Promise<SunanIndex>;
  /** The chunk holding the state's items; null when the state id is unknown. */
  getSunanChunkForState(stateId: number): Promise<SunanChunk | null>;
  getStateItems(stateId: number): Promise<StateItems | null>;
  /**
   * A sunnah item by id; when `fp` is given it must match — if the id now points to another item
   * (ids are renumbered between versions) the item is found by `fp`. Pass `stateHint` whenever it is known
   * (route param `st`, SunnahFav.stateId): a «بمعناها» member is not in the index, so without the hint the
   * first lookup of a version may read many chunks (once per version and session; see SunanLookup).
   */
  getSunnahItem(id: string, fp?: string | null, stateHint?: number | null): Promise<SunnahItem | null>;
  /** The copy (downloaded/bundled) and version in use per section. */
  getSources(): Promise<Record<Section, PackSourceRef | null>>;
  /** Forget memoised data (all sections, or only these). */
  clear(sections?: readonly Section[]): void;
}

/**
 * Where every sunnah item of ONE sunan version lives (id → chunk file, fp → chunk file), learnt from each
 * chunk the store reads. The index lists representatives only, so a «بمعناها» member — or a saved item
 * whose id was renumbered — can only be found by reading chunks; this map makes that a one-time cost per
 * version and session (and "not in this version" an instant answer once every chunk was seen).
 */
interface SunanLookup {
  version: string;
  byId: Map<string, string>;
  byFp: Map<string, string>;
  seen: Set<string>;
}

export function createPackStore(source: PackSource, cache: MemoCache = createMemoCache()): PackStore {
  async function currentRef(section: Section): Promise<PackSourceRef> {
    const ref = await source.resolve(section);
    if (!ref) throw new PackError("unavailable", `No ${section} content is available.`);
    return ref;
  }

  const keyOf = (section: Section, ref: PackSourceRef, file: string) => `${section}@${ref.version}/${file}`;

  async function parse<T>(section: Section, ref: PackSourceRef, file: string, expectKind: string): Promise<T> {
    const text = await source.readText(section, ref, file);
    let data: unknown;
    try {
      data = JSON.parse(text);
    } catch {
      throw new PackError("invalid", `${section}/${file} is not valid JSON.`);
    }
    const kind = (data as { kind?: unknown } | null)?.kind;
    if (kind !== expectKind) throw new PackError("invalid", `${section}/${file}: expected kind ${expectKind}.`);
    return data as T;
  }

  async function load<T>(section: Section, file: string, pin: boolean, expectKind: string): Promise<T> {
    const ref = await currentRef(section);
    return cache.get(keyOf(section, ref, file), () => parse<T>(section, ref, file, expectKind), { pin });
  }

  let lookup: SunanLookup | null = null;
  const lookupFor = (version: string): SunanLookup => {
    if (lookup?.version !== version) lookup = { version, byId: new Map(), byFp: new Map(), seen: new Set() };
    return lookup;
  };

  /**
   * A sunan chunk of the current version, registered in the lookup. `keep: false` (used while scanning)
   * does not insert it into the memo cache, so a scan does not evict the chunks the screens are using.
   */
  async function loadSunanChunk(file: string, keep = true): Promise<SunanChunk> {
    const ref = await currentRef("sunan");
    const key = keyOf("sunan", ref, file);
    const read = () => parse<SunanChunk>("sunan", ref, file, "sunan-chunk");
    const chunk = keep || cache.peek(key) ? await cache.get(key, read) : await read();
    const lk = lookupFor(ref.version);
    if (!lk.seen.has(file)) {
      lk.seen.add(file);
      for (const it of chunk.items) {
        if (!lk.byId.has(it.id)) lk.byId.set(it.id, file);
        if (it.fp && !lk.byFp.has(it.fp)) lk.byFp.set(it.fp, file);
      }
    }
    return chunk;
  }

  const getNamesIndex = () => load<NamesIndex>("names", "index.json", true, "names");
  const getSunanIndex = () => load<SunanIndex>("sunan", "index.json", true, "sunan");

  async function getNameDetail(id: number): Promise<NameDetail | null> {
    const index = await getNamesIndex();
    const chunk = index.chunks.find((c) => c.ids.includes(id));
    if (!chunk) return null;
    const data = await load<NamesChunk>("names", chunk.file, false, "names-chunk");
    return data.names.find((n) => n.id === id) ?? null;
  }

  async function getSunanChunkForState(stateId: number): Promise<SunanChunk | null> {
    const index = await getSunanIndex();
    const state = index.states.find((s) => s.id === stateId);
    if (!state) return null;
    return loadSunanChunk(state.chunk);
  }

  async function getStateItems(stateId: number): Promise<StateItems | null> {
    const index = await getSunanIndex();
    const state = index.states.find((s) => s.id === stateId);
    if (!state) return null;
    const chunk = await loadSunanChunk(state.chunk);
    return { state, items: chunk.items.filter((it) => it.stateId === stateId) };
  }

  async function getSunnahItem(id: string, fp?: string | null, stateHint?: number | null): Promise<SunnahItem | null> {
    const ref = await currentRef("sunan");
    const index = await getSunanIndex();
    const lk = lookupFor(ref.version);
    const wantFp = fp || null;
    // Holder object: assignments inside closures are not tracked by TS narrowing.
    const found: { fpOnly: SunnahItem | null } = { fpOnly: null };

    /** Returns the exact match in `items`, remembering an fp-only match (renumbered id) on the way. */
    const look = (items: readonly SunnahItem[]): SunnahItem | null => {
      for (const it of items) {
        if (wantFp) {
          if (it.fp !== wantFp) continue;
          if (it.id === id) return it;
          found.fpOnly ??= it;
        } else if (it.id === id) {
          return it;
        }
      }
      return null;
    };

    const tried = new Set<string>();
    const tryFile = async (file: string | undefined, keep = true): Promise<SunnahItem | null> => {
      if (!file || tried.has(file)) return null;
      tried.add(file);
      return look((await loadSunanChunk(file, keep)).items);
    };
    const stateFile = (stateId: number | null | undefined) =>
      stateId == null ? undefined : index.states.find((s) => s.id === stateId)?.chunk;

    // 1. Known places: the hinted state, where this version's chunks read so far put the fp / the id,
    //    the state listing the id (representatives), the stars.
    const candidates = [
      stateFile(stateHint),
      wantFp ? lk.byFp.get(wantFp) : undefined,
      lk.byId.get(id),
      index.states.find((s) => s.itemIds.includes(id))?.chunk,
      stateFile(index.stars.find((s) => s.id === id || (wantFp != null && s.fp === wantFp))?.stateId),
    ];
    for (const file of candidates) {
      const hit = await tryFile(file);
      if (hit) return hit;
      // The fingerprint is the identity: the item with this fp IS the saved sunnah under its new id.
      if (found.fpOnly) return found.fpOnly;
    }
    // 2. Chunks already read cannot hold it (their ids and fps are in the lookup): read only the others,
    //    once — after that every location of this version is known.
    for (const c of index.chunks) {
      if (lk.seen.has(c.file)) continue;
      const hit = await tryFile(c.file, false);
      if (hit) return hit;
      if (found.fpOnly) return found.fpOnly;
    }
    return found.fpOnly;
  }

  async function getSources(): Promise<Record<Section, PackSourceRef | null>> {
    const [names, sunan] = await Promise.all([source.resolve("names"), source.resolve("sunan")]);
    return { names, sunan };
  }

  function clear(sections?: readonly Section[]) {
    if (!sections || sections.includes("sunan")) lookup = null;
    if (!sections) return cache.clear();
    cache.clear((k) => sections.some((s) => k.startsWith(`${s}@`)));
  }

  return { getNamesIndex, getNameDetail, getSunanIndex, getSunanChunkForState, getStateItems, getSunnahItem, getSources, clear };
}
