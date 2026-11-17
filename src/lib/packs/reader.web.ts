/**
 * Web pack reader: bundled snapshot only (expo-file-system is not available on web), fetched from the
 * exported asset URL.
 */
import { Asset } from "expo-asset";

import { BUNDLED } from "./bundled";
import type { PackSourceRef, Section } from "./logic";
import type { PackSource } from "./store-core";

async function resolve(section: Section): Promise<PackSourceRef | null> {
  const b = BUNDLED[section];
  return b ? { kind: "bundled", version: b.version } : null;
}

async function readText(section: Section, _ref: PackSourceRef, file: string): Promise<string> {
  const mod = BUNDLED[section]?.files[file];
  if (mod == null) throw new Error(`Bundled pack file missing: ${section}/${file}`);
  const asset = Asset.fromModule(mod);
  const res = await fetch(asset.localUri ?? asset.uri);
  if (!res.ok) throw new Error(`HTTP ${res.status} for ${section}/${file}`);
  return res.text();
}

export const packSource: PackSource = { resolve, readText };
