/**
 * App settings (persisted on the device in AsyncStorage under SETTINGS_KEY). Pure TS: shape, defaults,
 * sanitising of stored JSON and merging. The React provider lives in src/hooks/use-settings.tsx.
 */

export const SETTINGS_KEY = "ilm.settings.v1";

export type ThemeSetting = "system" | "dark" | "light";

/** «عادي» / «كبير» / «أكبر». */
export const TEXT_SCALES = [1, 1.15, 1.3] as const;
export type TextScale = (typeof TEXT_SCALES)[number];
export const TEXT_SCALE_LABELS: Record<TextScale, string> = { 1: "عادي", 1.15: "كبير", 1.3: "أكبر" };

export interface MorningSettings {
  enabled: boolean;
  hour: number; // 0–23, local time
  minute: number; // 0–59
  /** The one-time «فعّل تذكير الصباح» card was dismissed. */
  dismissedPrompt: boolean;
}

export interface Settings {
  theme: ThemeSetting;
  textScale: TextScale;
  morning: MorningSettings;
}

export interface SettingsPatch {
  theme?: ThemeSetting;
  textScale?: TextScale;
  morning?: Partial<MorningSettings>;
}

export const DEFAULT_SETTINGS: Settings = {
  theme: "system",
  textScale: 1,
  morning: { enabled: false, hour: 7, minute: 0, dismissedPrompt: false },
};

function isObj(v: unknown): v is Record<string, unknown> {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}

function intIn(v: unknown, min: number, max: number, fallback: number): number {
  return typeof v === "number" && Number.isInteger(v) && v >= min && v <= max ? v : fallback;
}

function sanitizeMorning(raw: unknown, base: MorningSettings): MorningSettings {
  const m = isObj(raw) ? raw : {};
  return {
    enabled: typeof m.enabled === "boolean" ? m.enabled : base.enabled,
    hour: intIn(m.hour, 0, 23, base.hour),
    minute: intIn(m.minute, 0, 59, base.minute),
    dismissedPrompt: typeof m.dismissedPrompt === "boolean" ? m.dismissedPrompt : base.dismissedPrompt,
  };
}

/** Accepts anything (stored JSON, null, garbage) and returns valid settings. */
export function sanitizeSettings(raw: unknown): Settings {
  const r = isObj(raw) ? raw : {};
  const theme = r.theme === "system" || r.theme === "dark" || r.theme === "light" ? r.theme : DEFAULT_SETTINGS.theme;
  const textScale = (TEXT_SCALES as readonly number[]).includes(r.textScale as number)
    ? (r.textScale as TextScale)
    : DEFAULT_SETTINGS.textScale;
  return { theme, textScale, morning: sanitizeMorning(r.morning, DEFAULT_SETTINGS.morning) };
}

/** Applies a partial update (morning is merged field by field) and re-validates. */
export function mergeSettings(current: Settings, patch: SettingsPatch): Settings {
  return sanitizeSettings({
    ...current,
    ...patch,
    morning: { ...current.morning, ...(patch.morning ?? {}) },
  });
}

/** Parses the stored string (or null) into settings; never throws. */
export function parseStoredSettings(stored: string | null): Settings {
  if (!stored) return DEFAULT_SETTINGS;
  try {
    return sanitizeSettings(JSON.parse(stored));
  } catch {
    return DEFAULT_SETTINGS;
  }
}

/** Resolves the theme to use: "system" follows the device; an unknown device scheme means dark. */
export function resolveScheme(setting: ThemeSetting, system: string | null | undefined): "dark" | "light" {
  if (setting === "dark" || setting === "light") return setting;
  return system === "light" ? "light" : "dark";
}
