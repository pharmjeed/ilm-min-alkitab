/**
 * Design tokens — the platform's identity (ARCHITECTURE §5, from the website's app/globals.css).
 * Dark is the default. All type sizes are multiplied by the user text scale in AppText.
 */
import type { FontRole } from "./fonts";

export type Scheme = "dark" | "light";

interface BaseColors {
  bg: string;
  surface: string;
  surface2: string;
  /** Main text («cream» in dark, emerald-night in light). */
  text: string;
  muted: string;
  gold: string;
  emerald: string;
  line: string;
  error: string;
  info: string;
  /** «ما تتجنّبه» accent. */
  neg: string;
  /** Sunan result runs (cause runs use gold). */
  result: string;
}

const BASE: Record<Scheme, BaseColors> = {
  dark: {
    bg: "#0D1F1F",
    surface: "#122828",
    surface2: "#183333",
    text: "#F7ECD6",
    muted: "rgba(247,236,214,0.62)",
    gold: "#D4A449",
    emerald: "#2F6B5E",
    line: "rgba(212,164,73,0.22)",
    error: "#B4443C",
    info: "#3E7C8A",
    neg: "#C9826B",
    result: "#8BE0A8",
  },
  light: {
    bg: "#F5E9D0",
    surface: "#FBF3E3",
    surface2: "#F1E3C6",
    text: "#0D1F1F",
    muted: "rgba(13,31,31,0.64)",
    gold: "#846008",
    emerald: "#2F6B5E",
    line: "rgba(184,134,11,0.28)",
    error: "#B4443C",
    info: "#3E7C8A",
    neg: "#A2482B",
    result: "#1F7A4D",
  },
};

/** "#RRGGBB" + alpha → "rgba(r,g,b,a)". */
export function withAlpha(hex: string, alpha: number): string {
  const h = hex.replace("#", "");
  const n = parseInt(h.length === 3 ? h.replace(/./g, "$&$&") : h, 16);
  return `rgba(${(n >> 16) & 255},${(n >> 8) & 255},${n & 255},${alpha})`;
}

export interface Colors extends BaseColors {
  /** Text on a gold fill (primary buttons, active pills, ★ badge). */
  onGold: string;
  gold5: string;
  gold10: string;
  gold15: string;
  gold30: string;
  /** Verse and door card borders. */
  gold35: string;
  /** Page-header block border. */
  gold40: string;
  /** Chips. */
  gold45: string;
  /** Back pill. */
  gold50: string;
  /** Bridge-box start border, hover. */
  gold60: string;
  emerald20: string;
  /** Hadith card border. */
  emerald50: string;
  emerald60: string;
  text90: string;
  /** Skeleton blocks. */
  skeleton: string;
}

function build(scheme: Scheme): Colors {
  const b = BASE[scheme];
  return {
    ...b,
    onGold: b.bg,
    gold5: withAlpha(b.gold, 0.05),
    gold10: withAlpha(b.gold, 0.1),
    gold15: withAlpha(b.gold, 0.15),
    gold30: withAlpha(b.gold, 0.3),
    gold35: withAlpha(b.gold, 0.35),
    gold40: withAlpha(b.gold, 0.4),
    gold45: withAlpha(b.gold, 0.45),
    gold50: withAlpha(b.gold, 0.5),
    gold60: withAlpha(b.gold, 0.6),
    emerald20: withAlpha(b.emerald, 0.2),
    emerald50: withAlpha(b.emerald, 0.5),
    emerald60: withAlpha(b.emerald, 0.6),
    text90: withAlpha(b.text, 0.9),
    skeleton: scheme === "dark" ? "rgba(247,236,214,0.08)" : "rgba(13,31,31,0.08)",
  };
}

export const COLORS: Record<Scheme, Colors> = { dark: build("dark"), light: build("light") };

export type ColorName = keyof Colors;

/** 4-pt grid. */
export const SPACE = { xs: 4, sm: 8, md: 12, lg: 16, xl: 24, xxl: 32 } as const;
export const PAGE_PADDING = 16;
export const RADIUS = { badge: 6, inner: 8, card: 12, hero: 16, pill: 999 } as const;
export const TOUCH_MIN = 44;
export const BORDER = 1;

export type TextVariant =
  | "caption"
  | "small"
  | "body"
  | "lead"
  | "h3"
  | "h2"
  | "h1"
  | "hero"
  | "quran"
  | "quranMuted"
  | "hadith";

export interface TypeSpec {
  size: number;
  lineHeight: number;
  role: FontRole;
  /** Default colour of the variant. */
  color: ColorName;
}

/**
 * Sizes from the website scale (step--1 14 · step-0 16 · step-1 20 · step-2 25.6 · step-3 33.6 · step-4 44.8).
 * Arabic needs generous line heights (descenders/marks) — keep them ≥ 1.5× for UI text.
 */
export const TYPE: Record<TextVariant, TypeSpec> = {
  caption: { size: 12, lineHeight: 20, role: "body", color: "muted" },
  small: { size: 14, lineHeight: 24, role: "body", color: "text" },
  body: { size: 16, lineHeight: 28, role: "body", color: "text" },
  lead: { size: 20, lineHeight: 34, role: "body", color: "text" },
  h3: { size: 20, lineHeight: 32, role: "display", color: "text" },
  h2: { size: 25.6, lineHeight: 40, role: "display", color: "text" },
  h1: { size: 33.6, lineHeight: 50, role: "display", color: "text" },
  hero: { size: 44.8, lineHeight: 66, role: "display", color: "gold" },
  quran: { size: 24, lineHeight: 50, role: "scripture", color: "text" },
  quranMuted: { size: 18, lineHeight: 36, role: "scripture", color: "muted" },
  hadith: { size: 19, lineHeight: 40, role: "scripture", color: "text" },
};

/** Status bar / system UI per scheme. */
export const STATUS_BAR: Record<Scheme, "light" | "dark"> = { dark: "light", light: "dark" };
