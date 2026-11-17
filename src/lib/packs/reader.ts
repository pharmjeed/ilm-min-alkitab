/**
 * Native pack reader: the active downloaded version when there is one (and its files exist), else the
 * bundled snapshot (Metro asset → local file). Web uses ./reader.web.ts.
 */
import { Asset } from "expo-asset";
import { File } from "expo-file-system";

import { BUNDLED } from "./bundled";
import { hasVersionFiles, loadPointer, versionDir } from "./fs-native";
import { effectiveSource, type PackSourceRef, type Section } from "./logic";
import type { PackSource } from "./store-core";

async function resolve(section: Section): Promise<PackSourceRef | null> {
  const bundled = BUNDLED[section]?.version ?? null;
  const src = effectiveSource(section, await loadPointer(), bundled);
  if (src?.kind === "downloaded" && !hasVersionFiles(section, src.version)) {
    // The folder vanished (e.g. restored backup): fall back to the bundled copy.
    return bundled ? { kind: "bundled", version: bundled } : null;
  }
  return src;
}

async function readText(section: Section, ref: PackSourceRef, file: string): Promise<string> {
  if (ref.kind === "downloaded") return new File(versionDir(section, ref.version), file).text();
  const mod = BUNDLED[section]?.files[file];
  if (mod == null) throw new Error(`Bundled pack file missing: ${section}/${file}`);
  // downloadAsync copies the asset into the cache (or fetches it from the dev server in Expo Go);
  // the cache is not guaranteed to persist, so this runs on every launch (cheap when present).
  const asset = await Asset.fromModule(mod).downloadAsync();
  return new File(asset.localUri ?? asset.uri).text();
}

export const packSource: PackSource = { resolve, readText };
