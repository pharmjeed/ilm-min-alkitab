import { describe, expect, it } from "vitest";

import { namesChunk1, namesChunk2, namesIndex, NAMES_VERSION } from "../__fixtures__/names";
import { sunanChunk1, sunanChunk2, sunanIndex, SUNAN_VERSION } from "../__fixtures__/sunan";
import type { PackSourceRef, Section } from "./logic";
import { createPackStore, PackError, type PackSource } from "./store-core";
import type { SunanChunk, SunanIndex, SunnahItem } from "./types";

function fakeSource(files: Record<string, unknown>, versions: Partial<Record<Section, string>>) {
  const reads: string[] = [];
  const source: PackSource = {
    async resolve(section) {
      const v = versions[section];
      return v ? ({ kind: "bundled", version: v } satisfies PackSourceRef) : null;
    },
    async readText(section, ref, file) {
      reads.push(`${section}/${file}`);
      const data = files[`${section}/${file}`];
      if (data === undefined) throw new Error(`missing ${section}/${file}`);
      return typeof data === "string" ? data : JSON.stringify(data);
    },
  };
  return { source, reads };
}

const ALL = {
  "names/index.json": namesIndex,
  "names/chunk-01.json": namesChunk1,
  "names/chunk-02.json": namesChunk2,
  "sunan/index.json": sunanIndex,
  "sunan/need-01.json": sunanChunk1,
  "sunan/need-02.json": sunanChunk2,
};
const VERSIONS = { names: NAMES_VERSION, sunan: SUNAN_VERSION };

const chunkPath = (k: number) => `sunan/need-${String(k).padStart(2, "0")}.json`;

/** n chunks; chunk k holds state k with representative "r<k>" and its «بمعناها» member "m<k>" (not indexed). */
function manyChunks(n: number): Record<string, unknown> {
  const files: Record<string, unknown> = {};
  const states: SunanIndex["states"] = [];
  const chunks: SunanIndex["chunks"] = [];
  const item = (id: string, stateId: number, extra: Partial<SunnahItem>): SunnahItem => ({
    id,
    fp: `fp${id}`,
    stateId,
    easy: `${id} ← ${id}`,
    explicit: true,
    ref: "مرجع",
    ...extra,
  });
  for (let k = 1; k <= n; k++) {
    const file = chunkPath(k).slice("sunan/".length);
    const chunk: SunanChunk = {
      schema: 1,
      kind: "sunan-chunk",
      version: SUNAN_VERSION,
      needId: k,
      stateIds: [k],
      items: [item(`r${k}`, k, { similar: [`m${k}`] }), item(`m${k}`, k, { repOf: `r${k}` })],
    };
    files[chunkPath(k)] = chunk;
    states.push({ ...sunanIndex.states[0]!, id: k, needId: k, title: `حالة ${k}`, itemIds: [`r${k}`], chunk: file });
    chunks.push({ file, bytes: 1, sha256: "0".repeat(64), needId: k, stateIds: [k] });
  }
  files["sunan/index.json"] = { ...sunanIndex, states, stars: [], chunks } satisfies SunanIndex;
  return files;
}

describe("pack store", () => {
  it("reads indexes once and name details via index.chunks", async () => {
    const { source, reads } = fakeSource(ALL, VERSIONS);
    const store = createPackStore(source);
    expect((await store.getNamesIndex()).names).toHaveLength(3);
    expect((await store.getNameDetail(3))?.name).toBe("الرحيم");
    expect((await store.getNameDetail(2))?.name).toBe("الرحمن");
    expect(await store.getNameDetail(99)).toBeNull();
    expect(reads).toEqual(["names/index.json", "names/chunk-02.json"]);
  });

  it("returns a state's items and the chunk for a state", async () => {
    const { source } = fakeSource(ALL, VERSIONS);
    const store = createPackStore(source);
    const s1 = await store.getStateItems(1);
    expect(s1?.state.title).toBe("أريد البركة في طعامي");
    expect(s1?.items.map((i) => i.id)).toEqual(["10", "11"]);
    expect((await store.getSunanChunkForState(3))?.needId).toBe(2);
    expect(await store.getStateItems(42)).toBeNull();
  });

  it("finds sunnah items by id, by fp after renumbering, and members by scanning", async () => {
    const { source, reads } = fakeSource(ALL, VERSIONS);
    const store = createPackStore(source);
    expect((await store.getSunnahItem("10", "fp0000000010"))?.id).toBe("10");
    expect((await store.getSunnahItem("11"))?.repOf).toBe("10"); // member: found in a loaded chunk
    // saved as id "12" in an old version, now "13" has a different fp: resolve by fp
    expect((await store.getSunnahItem("13", "fp0000000012"))?.id).toBe("12");
    // the id exists but the fingerprint does not: it is another sunnah now → null
    expect(await store.getSunnahItem("10", "fp-unknown")).toBeNull();
    expect(await store.getSunnahItem("nope")).toBeNull();
    expect(reads.filter((r) => r === "sunan/index.json")).toHaveLength(1);
  });

  it("uses the state hint first", async () => {
    const { source, reads } = fakeSource(ALL, VERSIONS);
    const store = createPackStore(source);
    expect((await store.getSunnahItem("13", null, 3))?.stateId).toBe(3);
    expect(reads).toEqual(["sunan/index.json", "sunan/need-02.json"]);
  });

  it("finds an un-indexed member by reading each chunk at most once per version", async () => {
    const { source, reads } = fakeSource(manyChunks(10), VERSIONS);
    const store = createPackStore(source);
    const chunkReads = () => reads.filter((r) => r !== "sunan/index.json");

    expect((await store.getSunnahItem("m7"))?.repOf).toBe("r7"); // no hint: reads until found
    expect(chunkReads()).toEqual([1, 2, 3, 4, 5, 6, 7].map(chunkPath));
    reads.length = 0;
    expect((await store.getSunnahItem("m3"))?.stateId).toBe(3); // located by the lookup
    expect(chunkReads()).toEqual([chunkPath(3)]);
    reads.length = 0;
    expect((await store.getSunnahItem("m9"))?.stateId).toBe(9); // only the chunks not read yet
    expect(chunkReads()).toEqual([8, 9].map(chunkPath));
    reads.length = 0;
    expect(await store.getSunnahItem("gone", "fp-gone")).toBeNull(); // removed sunnah: one pass over the rest
    expect(chunkReads()).toEqual([chunkPath(10)]);
    reads.length = 0;
    expect(await store.getSunnahItem("gone", "fp-gone")).toBeNull(); // every location is known now
    expect(await store.getSunnahItem("nope")).toBeNull();
    expect(chunkReads()).toEqual([]);
    // a saved member whose id was renumbered: found by fp in one read
    expect((await store.getSunnahItem("m5", "fpm6"))?.id).toBe("m6");
    expect(chunkReads()).toEqual([chunkPath(6)]);
    expect(reads.filter((r) => r === "sunan/index.json")).toHaveLength(0);
  });

  it("reads one chunk with a state hint and does not evict the screens' chunks while scanning", async () => {
    const { source, reads } = fakeSource(manyChunks(10), VERSIONS);
    const store = createPackStore(source);
    expect((await store.getSunnahItem("m7", "fpm7", 7))?.id).toBe("m7");
    expect(reads).toEqual(["sunan/index.json", chunkPath(7)]);
    reads.length = 0;
    await store.getStateItems(1); // a screen holds state 1
    expect((await store.getSunnahItem("m10"))?.id).toBe("m10");
    await store.getStateItems(1);
    expect(reads.filter((r) => r === chunkPath(1))).toHaveLength(1);
  });

  it("forgets item locations when the sunan section is cleared", async () => {
    const { source, reads } = fakeSource(manyChunks(4), VERSIONS);
    const store = createPackStore(source);
    await store.getSunnahItem("m4");
    store.clear(["names"]);
    reads.length = 0;
    await store.getSunnahItem("m2");
    expect(reads).toEqual([chunkPath(2)]);
    store.clear(["sunan"]);
    reads.length = 0;
    await store.getSunnahItem("m2");
    expect(reads).toEqual(["sunan/index.json", chunkPath(1), chunkPath(2)]);
  });

  it("reports unavailable and invalid content", async () => {
    const { source } = fakeSource({ "names/index.json": "{oops", "sunan/index.json": { kind: "names" } }, { names: "n", sunan: "s" });
    const store = createPackStore(source);
    await expect(store.getNamesIndex()).rejects.toBeInstanceOf(PackError);
    await expect(store.getSunanIndex()).rejects.toMatchObject({ code: "invalid" });
    const empty = createPackStore(fakeSource({}, {}).source);
    await expect(empty.getNamesIndex()).rejects.toMatchObject({ code: "unavailable" });
    expect(await empty.getSources()).toEqual({ names: null, sunan: null });
  });

  it("re-reads after clear (e.g. after a sync switched versions)", async () => {
    const { source, reads } = fakeSource(ALL, VERSIONS);
    const store = createPackStore(source);
    await store.getNamesIndex();
    store.clear(["names"]);
    await store.getNamesIndex();
    expect(reads).toEqual(["names/index.json", "names/index.json"]);
  });
});
