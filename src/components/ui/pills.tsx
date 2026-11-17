/**
 * Pill buttons, chips, badges and the ★ «ابدأ بهذه» badge (website: .btn-primary / .btn-secondary,
 * situation chips, NameCard badges).
 */
import type { Href } from "expo-router";
import { Pressable, View, type StyleProp, type ViewStyle } from "react-native";

import { RADIUS, SPACE, TOUCH_MIN, useTheme, type ColorName } from "@/theme";

import { AppText } from "./app-text";
import { openHref } from "./navigation";

export type PillVariant = "primary" | "secondary" | "outline";

export interface PillProps {
  label: string;
  onPress?: () => void;
  href?: Href;
  variant?: PillVariant;
  size?: "md" | "sm";
  /** Active state (tabs / toggles): gold fill. */
  selected?: boolean;
  disabled?: boolean;
  accessibilityLabel?: string;
  style?: StyleProp<ViewStyle>;
}

export function Pill({ label, onPress, href, variant = "secondary", size = "md", selected, disabled, accessibilityLabel, style }: PillProps) {
  const { colors } = useTheme();
  const filled = variant === "primary" || selected;
  const borderColor = filled ? colors.gold : variant === "outline" ? colors.gold45 : colors.line;
  const backgroundColor = filled ? colors.gold : variant === "outline" ? colors.gold5 : "transparent";
  const handle = onPress ?? (href ? () => openHref(href) : undefined);
  return (
    <Pressable
      onPress={handle}
      disabled={disabled || !handle}
      accessibilityRole="button"
      accessibilityLabel={accessibilityLabel ?? label}
      accessibilityState={{ selected: !!selected, disabled: !!disabled }}
      hitSlop={size === "sm" ? 4 : 0}
      style={({ pressed }) => [
        {
          minHeight: size === "md" ? TOUCH_MIN : 36,
          paddingHorizontal: size === "md" ? 20 : 14,
          paddingVertical: SPACE.xs,
          borderRadius: RADIUS.pill,
          borderWidth: 1,
          borderColor: pressed && !filled ? colors.gold60 : borderColor,
          backgroundColor: pressed && !filled ? colors.surface2 : backgroundColor,
          alignItems: "center",
          justifyContent: "center",
          opacity: disabled ? 0.5 : pressed && filled ? 0.85 : 1,
        },
        style,
      ]}
    >
      <AppText variant={size === "md" ? "body" : "small"} weight="medium" color={filled ? "onGold" : "text"} center>
        {label}
      </AppText>
    </Pressable>
  );
}

export interface ChipProps {
  label: string;
  onPress?: () => void;
  href?: Href;
  selected?: boolean;
  style?: StyleProp<ViewStyle>;
}

/** Small rounded chip (situations «ادعُ به حين:», «مداخل أخرى», filters). */
export function Chip({ label, onPress, href, selected, style }: ChipProps) {
  const { colors } = useTheme();
  const handle = onPress ?? (href ? () => openHref(href) : undefined);
  return (
    <Pressable
      onPress={handle}
      disabled={!handle}
      accessibilityRole="button"
      accessibilityState={{ selected: !!selected }}
      hitSlop={4}
      style={({ pressed }) => [
        {
          minHeight: 36,
          paddingHorizontal: SPACE.md,
          paddingVertical: SPACE.xs,
          borderRadius: RADIUS.pill,
          borderWidth: 1,
          borderColor: selected ? colors.gold : pressed ? colors.gold60 : colors.gold45,
          backgroundColor: selected ? colors.gold : pressed ? colors.gold10 : colors.gold5,
          justifyContent: "center",
        },
        style,
      ]}
    >
      <AppText variant="small" color={selected ? "onGold" : "text"} center>
        {label}
      </AppText>
    </Pressable>
  );
}

export type BadgeTone = "gold" | "emerald" | "muted" | "neg" | "error";

const TONE: Record<BadgeTone, { fg: ColorName; border: ColorName; bg: ColorName | null }> = {
  gold: { fg: "gold", border: "gold45", bg: "gold10" },
  emerald: { fg: "text", border: "emerald60", bg: "emerald20" },
  muted: { fg: "muted", border: "line", bg: null },
  neg: { fg: "neg", border: "neg", bg: null },
  error: { fg: "error", border: "error", bg: null },
};

export interface BadgeProps {
  label: string;
  tone?: BadgeTone;
  style?: StyleProp<ViewStyle>;
}

/** Small pill label: «12 موضعًا», «مركّب», «حديث», «شرحٌ قيد المراجعة»… */
export function Badge({ label, tone = "muted", style }: BadgeProps) {
  const { colors } = useTheme();
  const t = TONE[tone];
  return (
    <View
      style={[
        {
          alignSelf: "flex-start",
          paddingHorizontal: SPACE.sm,
          paddingVertical: 1,
          borderRadius: RADIUS.pill,
          borderWidth: 1,
          borderColor: colors[t.border],
          backgroundColor: t.bg ? colors[t.bg] : "transparent",
        },
        style,
      ]}
    >
      <AppText variant="caption" color={t.fg} tabular>
        {label}
      </AppText>
    </View>
  );
}

/** ★ «ابدأ بهذه» — gold fill, background-coloured text, radius 6. */
export function StarBadge({ style }: { style?: StyleProp<ViewStyle> }) {
  const { colors } = useTheme();
  return (
    <View
      accessibilityLabel="ابدأ بهذه"
      style={[
        { alignSelf: "flex-start", backgroundColor: colors.gold, borderRadius: RADIUS.badge, paddingHorizontal: SPACE.sm, paddingVertical: 1 },
        style,
      ]}
    >
      <AppText variant="caption" weight="bold" color="onGold">
        ★ ابدأ بهذه
      </AppText>
    </View>
  );
}
