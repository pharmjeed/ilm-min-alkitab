import type { Section } from "./logic";

/** One section of the bundled snapshot (see scripts/gen-bundled.mjs → ./bundled.ts). */
export interface BundledSection {
  /** index.json's `version`. */
  version: string;
  /** "index.json" / "chunk-01.json" … → Metro asset module of the matching *.pack file. */
  files: Record<string, number>;
}

export type BundledPacks = Record<Section, BundledSection | null>;
