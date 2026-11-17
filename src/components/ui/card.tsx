/**
 * Card (surface box with a 1px border; tones for verse / hadith / hero / avoid / notice) and
 * PressableRow (list row with a trailing gold «… ←» meta).
 */
import type { Href } from "expo-router";
import type { ReactNode } from "react";
import { Pressable, View, type StyleProp, type ViewStyle } from "react-native";

import { RADIUS, SPACE, TOUCH_MIN, useTheme, type Colors } from "@/theme";

import { AppText } from "./app-text";
import { openHref } from "./navigation";

/**
 * default: line border · gold: verse / door card (gold 35%) · hero: page header block (radius 16, gold 40%)
 * hadith: emerald 50% border · avoid: 3px «neg» start border · notice: gold 45% border on gold 5% fill.
 */
export type CardTone = "default" | "gold" | "hero" | "hadith" | "avoid" | "notice";

function toneStyle(tone: CardTone, c: Colors): ViewStyle {
  switch (tone) {
    case "gold":
      return { borderColor: c.gold35 };
    case "hero":
      return { borderColor: c.gold40, borderRadius: RADIUS.hero };
    case "hadith":
      return { borderColor: c.emerald50 };
    case "avoid":
      return { borderColor: c.line, borderStartWidth: 3, borderStartColor: c.neg };
    case "notice":
      return { borderColor: c.gold45, backgroundColor: c.gold5 };
    default:
      return { borderColor: c.line };
  }
}

export interface CardProps {
  children: ReactNode;
  tone?: CardTone;
  onPress?: () => void;
  href?: Href;
  /** Inner padding (default 16). */
  padding?: number;
  gap?: number;
  accessibilityLabel?: string;
  style?: StyleProp<ViewStyle>;
}

export function Card({ children, tone = "default", onPress, href, padding = SPACE.lg, gap = SPACE.sm, accessibilityLabel, style }: CardProps) {
  const { colors } = useTheme();
  const base: ViewStyle = {
    borderWidth: 1,
    borderRadius: RADIUS.card,
    backgroundColor: colors.surface,
    padding,
    gap,
    ...toneStyle(tone, colors),
  };
  const handle = onPress ?? (href ? () => openHref(href) : undefined);
  if (!handle) return <View style={[base, style]}>{children}</View>;
  return (
    <Pressable
      onPress={handle}
      accessibilityRole="button"
      accessibilityLabel={accessibilityLabel}
      style={({ pressed }) => [base, pressed && { backgroundColor: colors.surface2, borderColor: colors.gold60 }, style]}
    >
      {children}
    </Pressable>
  );
}

export interface PressableRowProps {
  title: string;
  subtitle?: string;
  /** Trailing gold text; «←» is appended («3 أسماء ←»). Without meta only «←» is shown. */
  meta?: string;
  onPress?: () => void;
  href?: Href;
  /** «ما تتجنّبه» rows: 3px neg start border. */
  avoid?: boolean;
  /** Leading element (number circle, badge…). */
  leading?: ReactNode;
  /** Max lines of the subtitle (default 2). */
  subtitleLines?: number;
  style?: StyleProp<ViewStyle>;
}

export function PressableRow({ title, subtitle, meta, onPress, href, avoid, leading, subtitleLines = 2, style }: PressableRowProps) {
  const { colors } = useTheme();
  const handle = onPress ?? (href ? () => openHref(href) : undefined);
  return (
    <Pressable
      onPress={handle}
      disabled={!handle}
      accessibilityRole="button"
      accessibilityLabel={[title, subtitle, meta].filter(Boolean).join("، ")}
      style={({ pressed }) => [
        {
          flexDirection: "row",
          alignItems: "center",
          gap: SPACE.md,
          minHeight: TOUCH_MIN + 8,
          paddingHorizontal: SPACE.lg,
          paddingVertical: SPACE.md,
          borderRadius: RADIUS.card,
          borderWidth: 1,
          borderColor: pressed ? colors.gold60 : colors.line,
          backgroundColor: pressed ? colors.surface2 : colors.surface,
        },
        avoid && { borderStartWidth: 3, borderStartColor: colors.neg },
        style,
      ]}
    >
      {leading}
      <View style={{ flex: 1, gap: 2 }}>
        <AppText>{title}</AppText>
        {subtitle ? (
          <AppText variant="caption" numberOfLines={subtitleLines}>
            {subtitle}
          </AppText>
        ) : null}
      </View>
      <AppText variant="caption" color="gold" tabular>
        {meta ? `${meta} ←` : "←"}
      </AppText>
    </Pressable>
  );
}

/** 40px circle with the number (name id, door number) — website NameCard / FeelCard. */
export function NumberCircle({ n, size = 40 }: { n: number | string; size?: number }) {
  const { colors } = useTheme();
  return (
    <View
      style={{
        width: size,
        height: size,
        borderRadius: size / 2,
        borderWidth: 1,
        borderColor: colors.gold60,
        alignItems: "center",
        justifyContent: "center",
      }}
    >
      <AppText variant="small" color="gold" tabular center>
        {String(n)}
      </AppText>
    </View>
  );
}
