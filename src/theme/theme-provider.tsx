/**
 * Theme context: resolves the colour scheme (setting system|dark|light — "system" follows the device,
 * dark when the device does not say) and exposes tokens + the user text scale.
 */
import { createContext, use, useMemo, type ReactNode } from "react";
import { useColorScheme } from "react-native";

import { useSettings } from "@/hooks/use-settings";
import { resolveScheme, type TextScale, type ThemeSetting } from "@/lib/settings";

import { COLORS, type Colors, type Scheme } from "./tokens";

export interface ThemeValue {
  scheme: Scheme;
  colors: Colors;
  textScale: TextScale;
  setting: ThemeSetting;
}

const ThemeContext = createContext<ThemeValue | null>(null);

export function ThemeProvider({ children }: { children: ReactNode }) {
  const system = useColorScheme();
  const { settings } = useSettings();
  const scheme = resolveScheme(settings.theme, system);
  const value = useMemo<ThemeValue>(
    () => ({ scheme, colors: COLORS[scheme], textScale: settings.textScale, setting: settings.theme }),
    [scheme, settings.textScale, settings.theme],
  );
  return <ThemeContext value={value}>{children}</ThemeContext>;
}

const FALLBACK: ThemeValue = { scheme: "dark", colors: COLORS.dark, textScale: 1, setting: "system" };

/** Current theme (dark defaults outside the provider, e.g. in an error boundary). */
export function useTheme(): ThemeValue {
  return use(ThemeContext) ?? FALLBACK;
}
