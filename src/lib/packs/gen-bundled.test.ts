/// <reference types="node" />
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

import { afterEach, describe, expect, it } from "vitest";

import { namesChunk1, namesChunk2, namesIndex } from "../__fixtures__/names";

const SCRIPT = resolve(__dirname, "../../../scripts/gen-bundled.mjs");
const dirs: string[] = [];

function setup(files: Record<string, unknown>) {
  const root = mkdtempSync(join(tmpdir(), "gen-bundled-"));
  dirs.push(root);
  mkdirSync(join(root, "packs", "names"), { recursive: true });
  mkdirSync(join(root, "packs", "sunan"), { recursive: true }); // empty section folder
  for (const [rel, data] of Object.entries(files)) {
    writeFileSync(join(root, "packs", rel), typeof data === "string" ? data : JSON.stringify(data));
  }
  mkdirSync(join(root, "src", "lib", "packs"), { recursive: true });
  return root;
}

function run(root: string, ...extra: string[]) {
  const out = join(root, "src", "lib", "packs", "bundled.ts");
  const r = spawnSync(process.execPath, [SCRIPT, "--packs", join(root, "packs"), "--out", out, ...extra], { encoding: "utf8" });
  return { ...r, out };
}

afterEach(() => {
  for (const d of dirs.splice(0)) rmSync(d, { recursive: true, force: true });
});

describe("scripts/gen-bundled.mjs", () => {
  it("writes a sorted BUNDLED map, index first, and null for empty sections", () => {
    const root = setup({
      "names/chunk-02.pack": namesChunk2,
      "names/index.pack": "\uFEFF" + JSON.stringify(namesIndex),
      "names/chunk-01.pack": namesChunk1,
    });
    const r = run(root);
    expect(r.status).toBe(0);
    const text = readFileSync(r.out, "utf8");
    expect(text).toContain(`version: "${namesIndex.version}"`);
    expect(text).toContain("  sunan: null,");
    const order = [...text.matchAll(/"([a-z0-9-]+\.json)": require\("([^"]+)"\)/g)].map((m) => [m[1], m[2]]);
    expect(order).toEqual([
      ["index.json", "../../../packs/names/index.pack"],
      ["chunk-01.json", "../../../packs/names/chunk-01.pack"],
      ["chunk-02.json", "../../../packs/names/chunk-02.pack"],
    ]);
    // deterministic: a second run does not change it, and --check passes
    expect(run(root).stdout).toMatch(/unchanged/);
    expect(run(root, "--check").status).toBe(0);
  });

  it("fails when a chunk listed in the index is missing", () => {
    const root = setup({ "names/index.pack": namesIndex, "names/chunk-01.pack": namesChunk1 });
    const r = run(root);
    expect(r.status).toBe(1);
    expect(r.stderr).toMatch(/chunk-02\.json/);
  });

  it("fails on chunk files without an index", () => {
    const root = setup({ "names/chunk-01.pack": namesChunk1 });
    expect(run(root).status).toBe(1);
  });
});
