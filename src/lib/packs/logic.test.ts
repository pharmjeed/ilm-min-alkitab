import { describe, expect, it } from "vitest";

import { createMemoCache } from "./cache";
import { bumpDataEpoch, createObservable, getDataEpoch, onPacksChanged } from "./events";
import {
  EMPTY_POINTER,
  effectiveSource,
  isSafeFileName,
  isSafeVersion,
  manifestUrl,
  packAssetName,
  packFileUrl,
  parseManifest,
  parsePointer,
  planSection,
  referencedFiles,
  staleVersions,
  withEntry,
  withoutEntry,
} from "./logic";
import type { SectionManifest } from "./types";

const sha = (c: string) => c.repeat(64);
const section = (version: string, schema = 1): SectionManifest => ({
  version,
  publishedAt: "2026-11-17T00:00:00Z",
  schema: schema as 1,
  files: [
    { file: "index.json", bytes: 10, sha256: sha("a") },
    { file: "chunk-01.json", bytes: 20, sha256: sha("b") },
  ],
  totalBytes: 30,
});

describe("urls and names", () => {
  it("builds platform urls", () => {
    expect(manifestUrl("https://x.app/")).toBe("https://x.app/api/app/v1/manifest");
    expect(packFileUrl("https://x.app", "sunan", "sunan-abc", "need-12-2.json")).toBe(
      "https://x.app/api/app/v1/packs/sunan/sunan-abc/need-12-2.json",
    );
    expect(packAssetName("chunk-01.json")).toBe("chunk-01.pack");
  });
  it("rejects unsafe file names and versions", () => {
    expect(isSafeFileName("need-12-2.json")).toBe(true);
    expect(isSafeFileName("../x.json")).toBe(false);
    expect(isSafeFileName("a/b.json")).toBe(false);
    expect(isSafeFileName("index.pack")).toBe(false);
    expect(isSafeVersion("names-0123456789ab")).toBe(true);
    expect(isSafeVersion("..")).toBe(false);
    expect(isSafeVersion("a/b")).toBe(false);
  });
});

describe("parseManifest", () => {
  it("accepts a valid manifest and lower-cases hashes", () => {
    const m = parseManifest({
      schema: 1,
      generatedAt: "x",
      sections: { names: { ...section("names-1"), files: [{ file: "index.json", bytes: 1, sha256: sha("A") }] } },
    });
    expect(m?.sections.names?.files[0]?.sha256).toBe(sha("a"));
    expect(m?.sections.sunan).toBeUndefined();
  });
  it("drops malformed sections and rejects garbage", () => {
    expect(parseManifest(null)).toBeNull();
    expect(parseManifest({ schema: 1 })).toBeNull();
    const bad = parseManifest({
      schema: 1,
      sections: {
        names: { ...section("names-1"), files: [{ file: "chunk-01.json", bytes: 1, sha256: sha("a") }] }, // index not first
        sunan: { ...section("sunan-1"), files: [{ file: "../index.json", bytes: 1, sha256: sha("a") }] },
      },
    });
    expect(bad).toEqual({ schema: 1, generatedAt: "", sections: {} });
    const dup = parseManifest({
      schema: 1,
      sections: { names: { ...section("n"), files: [section("n").files[0], section("n").files[0]] } },
    });
    expect(dup?.sections.names).toBeUndefined();
  });
});

describe("pointer and version selection", () => {
  it("parses tolerantly", () => {
    expect(parsePointer("x")).toEqual(EMPTY_POINTER);
    expect(parsePointer({ v: 1, sections: { names: { version: "../x", bundled: null } } })).toEqual(EMPTY_POINTER);
    const p = parsePointer({ v: 1, sections: { names: { version: "names-2", bundled: "names-1", activatedAt: "t" } } });
    expect(p.sections.names).toEqual({ version: "names-2", bundled: "names-1", activatedAt: "t" });
  });
  it("uses the download only while the bundled snapshot is the one it was downloaded over", () => {
    const p = withEntry(EMPTY_POINTER, "names", { version: "names-2", bundled: "names-1", activatedAt: "" });
    expect(effectiveSource("names", p, "names-1")).toEqual({ kind: "downloaded", version: "names-2" });
    expect(effectiveSource("names", p, "names-3")).toEqual({ kind: "bundled", version: "names-3" });
    expect(effectiveSource("sunan", p, null)).toBeNull();
    expect(withoutEntry(p, "names")).toEqual(EMPTY_POINTER);
  });
  it("plans sync per section", () => {
    const cur = { kind: "bundled" as const, version: "names-1" };
    expect(planSection(undefined, cur, "names-1")).toEqual({ action: "none", reason: "absent" });
    expect(planSection(section("names-2", 2), cur, "names-1")).toEqual({ action: "none", reason: "schema" });
    expect(planSection(section("names-1"), cur, "names-1")).toEqual({ action: "none", reason: "current" });
    expect(planSection(section("names-1"), { kind: "downloaded", version: "names-2" }, "names-1")).toEqual({
      action: "use-bundled",
      version: "names-1",
    });
    expect(planSection(section("names-2"), cur, "names-1")).toMatchObject({ action: "download", version: "names-2" });
    expect(planSection(section("names-2"), null, null)).toMatchObject({ action: "download" });
  });
  it("lists stale folders and referenced chunk files", () => {
    expect(staleVersions(["b", "a", "keep"], "keep")).toEqual(["a", "b"]);
    expect(staleVersions(["a"], null)).toEqual(["a"]);
    expect(referencedFiles({ chunks: [{ file: "chunk-01.json" }, { nope: 1 }] })).toEqual(["chunk-01.json"]);
    expect(referencedFiles(null)).toEqual([]);
  });
});

describe("memo cache", () => {
  it("dedupes concurrent loads, evicts unpinned LRU entries and forgets failures", async () => {
    const cache = createMemoCache(2);
    let loads = 0;
    const load = (v: string) => async () => {
      loads++;
      return v;
    };
    const [a, b] = await Promise.all([cache.get("x", load("x")), cache.get("x", load("x"))]);
    expect([a, b, loads]).toEqual(["x", "x", 1]);
    await cache.get("idx", load("idx"), { pin: true });
    await cache.get("c1", load("c1"));
    await cache.get("x", load("x")); // refresh x
    await cache.get("c2", load("c2")); // evicts c1 (oldest unpinned)
    expect(cache.keys().sort()).toEqual(["c2", "idx", "x"]);
    cache.clear((k) => k.startsWith("c"));
    expect(cache.keys().sort()).toEqual(["idx", "x"]);
    const fresh = createMemoCache();
    await expect(fresh.get("bad", () => Promise.reject(new Error("boom")))).rejects.toThrow("boom");
    expect(fresh.peek("bad")).toBeUndefined();
  });
});

describe("events", () => {
  it("bumps the epoch and notifies listeners", () => {
    const seen: number[] = [];
    const off = onPacksChanged((c) => seen.push(c.epoch));
    const e0 = getDataEpoch();
    expect(bumpDataEpoch(["names"])).toBe(e0 + 1);
    off();
    bumpDataEpoch(["sunan"]);
    expect(seen).toEqual([e0 + 1]);
  });
  it("observable notifies subscribers", () => {
    const o = createObservable(1);
    let n = 0;
    const off = o.subscribe(() => n++);
    o.set(2);
    off();
    o.set(3);
    expect([o.get(), n]).toEqual([3, 1]);
  });
});
