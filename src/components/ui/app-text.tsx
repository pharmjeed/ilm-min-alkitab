/**
 * AppText — the ONLY place that sets text alignment (ARCHITECTURE §6):
 *   textAlign: I18nManager.isRTL ? "left" : "right"  (in native RTL "left" means start), writingDirection rtl.
 * Variants follow the website type scale; sizes are multiplied by the user text scale.
 * Quran / hadith text uses the `quran`, `quranMuted`, `hadith` variants (Amiri) — never a body font.
 */
import { I18nManager, Text, type TextProps, type TextStyle } from "react-native";

import { TYPE, fontFamily, useTheme, type ColorName, type FontRole, type FontWeight, type TextVariant } from "@/theme";

/** Start alignment for RTL text in every runtime (native RTL, Expo Go on a LTR phone, web). */
export const TEXT_START: TextStyle["textAlign"] = I18nManager.isRTL ? "left" : "right";

/** System font scaling still applies on top of our own text scale, capped to keep layouts usable. */
const MAX_SYSTEM_SCALE = 1.4;

export interface AppTextProps extends TextProps {
  variant?: TextVariant;
  /** Token colour; defaults to the variant's colour (muted for caption, gold for hero…). */
  color?: ColorName;
  /** Display headings default to medium, everything else to regular. */
  weight?: FontWeight;
  center?: boolean;
  /** Tabular (fixed-width) digits for counters. */
  tabular?: boolean;
}

export function AppText({ variant = "body", color, weight, center, tabular, style, ...rest }: AppTextProps) {
  const { colors, textScale } = useTheme();
  const spec = TYPE[variant];
  const base: TextStyle = {
    fontFamily: fontFamily(spec.role, weight ?? (spec.role === "display" ? "medium" : "regular")),
    fontSize: spec.size * textScale,
    lineHeight: Math.round(spec.lineHeight * textScale),
    color: colors[color ?? spec.color],
    textAlign: center ? "center" : TEXT_START,
    writingDirection: "rtl",
    ...(tabular ? { fontVariant: ["tabular-nums"] } : null),
  };
  return <Text maxFontSizeMultiplier={MAX_SYSTEM_SCALE} {...rest} style={[base, style]} />;
}

export interface SpanProps extends TextProps {
  /** Font role of the surrounding AppText (bold Amiri inside Quran text needs "scripture"). */
  fontRole?: FontRole;
  weight?: FontWeight;
  color?: ColorName;
}

/** Inline run inside an AppText (bold, gold highlight…). Inherits size and alignment from the parent. */
export function Span({ fontRole = "body", weight, color, style, ...rest }: SpanProps) {
  const { colors } = useTheme();
  const s: TextStyle = {
    ...(weight ? { fontFamily: fontFamily(fontRole, weight) } : null),
    ...(color ? { color: colors[color] } : null),
  };
  return <Text {...rest} style={[s, style]} />;
}
