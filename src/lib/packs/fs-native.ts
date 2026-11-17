/**
 * On-device layout of downloaded packs (native only — expo-file-system SDK 58 File/Directory/Paths API):
 *
 *   <document>/packs/active.json                 pointer (PackPointer), written atomically
 *   <document>/packs/<section>/<version>/<file>  verified files of a downloaded version
 *   <cache>/packs-staging/<section>-<version>-<t>/  downloads in progress (never read by the app)
 */
import { Directory, File, Paths } from "expo-file-system";

import { EMPTY_POINTER, parsePointer, type PackPointer, type Section } from "./logic";

export const packsRoot = () => new Directory(Paths.document, "packs");
export const sectionDir = (section: Section) => new Directory(Paths.document, "packs", section);
export const versionDir = (section: Section, version: string) => new Directory(Paths.document, "packs", section, version);
export const stagingRoot = () => new Directory(Paths.cache, "packs-staging");
const pointerFile = () => new File(Paths.document, "packs", "active.json");

/** A downloaded version is usable when its index.json is there (commit moves files before the pointer switch). */
export const hasVersionFiles = (section: Section, version: string) => new File(versionDir(section, version), "index.json").exists;

let cached: PackPointer | null = null;

/** The current pointer (memoised; a missing or corrupt file means "bundled everywhere"). */
export async function loadPointer(): Promise<PackPointer> {
  if (cached) return cached;
  let pointer = EMPTY_POINTER;
  try {
    const f = pointerFile();
    if (f.exists) pointer = parsePointer(JSON.parse(await f.text()));
  } catch {
    pointer = EMPTY_POINTER;
  }
  cached = pointer;
  return pointer;
}

/** Write to a temp file, then rename over active.json — readers never see a half-written pointer. */
export async function savePointer(pointer: PackPointer): Promise<void> {
  const root = packsRoot();
  root.create({ intermediates: true, idempotent: true });
  const tmp = new File(root, "active.json.tmp");
  if (tmp.exists) tmp.delete();
  tmp.create();
  await tmp.write(JSON.stringify(pointer));
  await tmp.move(pointerFile(), { overwrite: true });
  cached = pointer;
}
