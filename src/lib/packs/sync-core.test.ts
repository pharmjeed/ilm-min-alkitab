/// <reference types="node" />
import { createHash } from "node:crypto";

import { describe, expect, it } from "vitest";

import { EMPTY_POINTER, type PackPointer, type Section } from "./logic";
import { runSync, type SyncIO } from "./sync-core";

const API = "https://example.test";
const sha = (s: string) => createHash("sha256").update(s, "utf8").digest("hex");

/** Server-side files of a published version. */
function published(section: Section, version: string, chunks: Record<string, string>) {
  const index = JSON.stringify({ kind: section, version, chunks: Object.keys(chunks).map((file) => ({ file })) });
  const files: Record<string, string> = { "index.json": index, ...chunks };
  return {
    files,
    manifest: {
      version,
      publishedAt: "2026-11-17T00:00:00Z",
      schema: 1,
      files: Object.entries(files).map(([file, text]) => ({ file, bytes: text.length, sha256: sha(text) })),
      totalBytes: 0,
    },
  };
}

/** In-memory device file system + network. */
function fakeIO(opts: {
  manifest?: unknown;
  status?: number;
  offline?: boolean;
  server?: Record<string, string>; // url → body
  corrupt?: string; // url whose download is altered
  pointer?: PackPointer;
  dirs?: Record<string, string[]>; // section → versions present
  failPointerWrite?: boolean;
}) {
  let pointer = opts.pointer ?? EMPTY_POINTER;
  const dirs: Record<string, Set<string>> = { names: new Set(opts.dirs?.names), sunan: new Set(opts.dirs?.sunan) };
  const log: string[] = [];
  const io: SyncIO = {
    async fetchManifest(url) {
      log.push(`GET ${url}`);
      if (opts.offline) throw new Error("Network request failed");
      return { status: opts.status ?? 200, body: opts.manifest };
    },
    async readPointer() {
      return pointer;
    },
    async hasVersion(section, version) {
      return dirs[section]!.has(version);
    },
    async writePointer(p) {
      if (opts.failPointerWrite) throw new Error("disk full");
      log.push("pointer");
      pointer = p;
    },
    async stage(section, version) {
      const staged: Record<string, string> = {};
      return {
        async download(url, file) {
          const body = opts.server?.[url];
          if (body === undefined) throw new Error(`HTTP 404 ${url}`);
          staged[file] = url === opts.corrupt ? body + " " : body;
        },
        async sha256(file) {
          return sha(staged[file]!);
        },
        async readText(file) {
          return staged[file]!;
        },
        async commit() {
          log.push(`commit ${section}/${version}`);
          dirs[section]!.add(version);
        },
        async discard() {
          log.push(`discard ${section}/${version}`);
        },
      };
    },
    async listVersions(section) {
      return [...dirs[section]!];
    },
    async removeVersion(section, version) {
      log.push(`rm ${section}/${version}`);
      dirs[section]!.delete(version);
    },
  };
  return { io, log, getPointer: () => pointer, dirs };
}

const serverFor = (section: Section, p: ReturnType<typeof published>) =>
  Object.fromEntries(Object.entries(p.files).map(([f, t]) => [`${API}/api/app/v1/packs/${section}/${p.manifest.version}/${f}`, t]));

const bundled = { names: "names-b", sunan: null };
const now = () => new Date("2026-11-17T12:00:00Z");

describe("runSync", () => {
  it("is a no-op when the manifest is not deployed (404) or offline", async () => {
    const a = fakeIO({ status: 404 });
    expect(await runSync(a.io, { api: API, bundled, now })).toMatchObject({ status: "not-deployed", changed: [] });
    const b = fakeIO({ offline: true });
    expect(await runSync(b.io, { api: API, bundled, now })).toMatchObject({ status: "offline", changed: [] });
    expect(a.getPointer()).toBe(EMPTY_POINTER);
  });

  it("downloads, verifies, activates and cleans up a new version", async () => {
    const p = published("names", "names-2", { "chunk-01.json": '{"kind":"names-chunk"}' });
    const f = fakeIO({
      manifest: { schema: 1, sections: { names: p.manifest } },
      server: serverFor("names", p),
      dirs: { names: ["names-old"] },
    });
    const r = await runSync(f.io, { api: API, bundled, now });
    expect(r.status).toBe("ok");
    expect(r.changed).toEqual(["names"]);
    expect(f.getPointer().sections.names).toEqual({ version: "names-2", bundled: "names-b", activatedAt: now().toISOString() });
    expect([...f.dirs.names!]).toEqual(["names-2"]);
    expect(f.log.indexOf("commit names/names-2")).toBeLessThan(f.log.indexOf("pointer"));
    expect(r.sections.find((s) => s.section === "sunan")?.result).toBe("absent");
  });

  it("leaves the active content untouched when a hash does not match", async () => {
    const p = published("names", "names-2", { "chunk-01.json": "{}" });
    const server = serverFor("names", p);
    const pointer: PackPointer = { v: 1, sections: { names: { version: "names-1", bundled: "names-b", activatedAt: "" } } };
    const f = fakeIO({
      manifest: { schema: 1, sections: { names: p.manifest } },
      server,
      corrupt: Object.keys(server).find((u) => u.endsWith("chunk-01.json")),
      pointer,
      dirs: { names: ["names-1"] },
    });
    const r = await runSync(f.io, { api: API, bundled, now });
    expect(r.changed).toEqual([]);
    expect(r.sections[0]).toMatchObject({ section: "names", result: "failed" });
    expect(r.sections[0]?.error).toMatch(/sha256 mismatch/);
    expect(f.getPointer()).toBe(pointer);
    expect(f.log).toContain("discard names/names-2");
    expect([...f.dirs.names!]).toEqual(["names-1"]);
  });

  it("fails safely on a missing file and on an index that does not match the manifest", async () => {
    const p = published("names", "names-2", { "chunk-01.json": "{}" });
    const server = serverFor("names", p);
    delete server[Object.keys(server).find((u) => u.endsWith("chunk-01.json"))!];
    const f = fakeIO({ manifest: { schema: 1, sections: { names: p.manifest } }, server });
    expect((await runSync(f.io, { api: API, bundled, now })).sections[0]?.result).toBe("failed");
    expect(f.getPointer()).toBe(EMPTY_POINTER);

    // index claims another version
    const q = published("names", "names-3", {});
    const wrong = JSON.stringify({ kind: "names", version: "names-999", chunks: [] });
    const manifest = { ...q.manifest, files: [{ file: "index.json", bytes: wrong.length, sha256: sha(wrong) }] };
    const g = fakeIO({
      manifest: { schema: 1, sections: { names: manifest } },
      server: { [`${API}/api/app/v1/packs/names/names-3/index.json`]: wrong },
    });
    const r = await runSync(g.io, { api: API, bundled, now });
    expect(r.sections[0]?.error).toMatch(/does not match/);
    expect(g.getPointer()).toBe(EMPTY_POINTER);
  });

  it("keeps the old pointer when writing the pointer fails", async () => {
    const p = published("names", "names-2", {});
    const f = fakeIO({ manifest: { schema: 1, sections: { names: p.manifest } }, server: serverFor("names", p), failPointerWrite: true });
    const r = await runSync(f.io, { api: API, bundled, now });
    expect(r.changed).toEqual([]);
    expect(f.getPointer()).toBe(EMPTY_POINTER);
  });

  it("skips sections that need a newer app and the current version", async () => {
    const p = published("names", "names-2", {});
    const f = fakeIO({ manifest: { schema: 1, sections: { names: { ...p.manifest, schema: 2 } } } });
    expect((await runSync(f.io, { api: API, bundled, now })).sections[0]?.result).toBe("schema");
    const g = fakeIO({ manifest: { schema: 1, sections: { names: { ...p.manifest, version: "names-b" } } } });
    expect((await runSync(g.io, { api: API, bundled, now })).sections[0]?.result).toBe("current");
  });

  it("reverts to the bundled snapshot when it is the published version", async () => {
    const p = published("names", "names-b", {});
    const pointer: PackPointer = { v: 1, sections: { names: { version: "names-1", bundled: "names-b", activatedAt: "" } } };
    const f = fakeIO({ manifest: { schema: 1, sections: { names: p.manifest } }, pointer, dirs: { names: ["names-1"] } });
    const r = await runSync(f.io, { api: API, bundled, now });
    expect(r.changed).toEqual(["names"]);
    expect(r.sections[0]?.result).toBe("reverted");
    expect(f.getPointer().sections.names).toBeUndefined();
    expect([...f.dirs.names!]).toEqual([]);
  });

  it("downloads again a version whose folder vanished instead of taking it as current", async () => {
    const p = published("names", "names-1", { "chunk-01.json": '{"kind":"names-chunk"}' });
    const pointer: PackPointer = { v: 1, sections: { names: { version: "names-1", bundled: "names-b", activatedAt: "" } } };
    const f = fakeIO({ manifest: { schema: 1, sections: { names: p.manifest } }, server: serverFor("names", p), pointer, dirs: { names: [] } });
    const r = await runSync(f.io, { api: API, bundled, now });
    expect(r.sections[0]).toMatchObject({ section: "names", result: "updated", version: "names-1" });
    expect(r.changed).toEqual(["names"]);
    expect([...f.dirs.names!]).toEqual(["names-1"]);
    expect(f.getPointer().sections.names?.activatedAt).toBe(now().toISOString());

    // the same pointer with its folder present stays current (nothing downloaded)
    const g = fakeIO({ manifest: { schema: 1, sections: { names: p.manifest } }, server: serverFor("names", p), pointer, dirs: { names: ["names-1"] } });
    const s = await runSync(g.io, { api: API, bundled, now });
    expect(s.sections[0]?.result).toBe("current");
    expect(g.getPointer()).toBe(pointer);
    expect(g.log.filter((l) => l.startsWith("commit"))).toEqual([]);
  });

  it("a vanished folder whose version is no longer published: back to the bundled snapshot", async () => {
    const p = published("names", "names-b", {});
    const pointer: PackPointer = { v: 1, sections: { names: { version: "names-1", bundled: "names-b", activatedAt: "" } } };
    const f = fakeIO({ manifest: { schema: 1, sections: { names: p.manifest } }, pointer, dirs: { names: [] } });
    const r = await runSync(f.io, { api: API, bundled, now });
    expect(r.sections[0]?.result).toBe("current");
    expect(r.changed).toEqual([]);
  });

  it("reports an invalid manifest", async () => {
    const f = fakeIO({ manifest: { nope: true } });
    expect(await runSync(f.io, { api: API, bundled, now })).toMatchObject({ status: "error", error: "invalid manifest" });
  });
});
