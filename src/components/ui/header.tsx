/**
 * ScreenHeader (back pill «→ رجوع» at the start = right edge, then kicker / title / subtitle),
 * BackPill and SectionTitle («المزيد ←»). Every stack screen uses ScreenHeader instead of a native
 * header so Expo Go, builds and web look the same.
 */
import type { Href } from "expo-router";
import type { ReactNode } from "react";
import { Pressable, View } from "react-native";

import { RADIUS, SPACE, TOUCH_MIN, useTheme } from "@/theme";

import { AppText } from "./app-text";
import { goBack, openHref } from "./navigation";

export interface BackPillProps {
  /** Where to go when there is no history (deep link / notification). Default: «يومي». */
  fallbackHref?: Href;
  label?: string;
}

export function BackPill({ fallbackHref = "/", label = "→ رجوع" }: BackPillProps) {
  const { colors } = useTheme();
  return (
    <Pressable
      onPress={() => goBack(fallbackHref)}
      accessibilityRole="button"
      accessibilityLabel="رجوع"
      style={({ pressed }) => ({
        alignSelf: "flex-start",
        minHeight: TOUCH_MIN,
        paddingHorizontal: SPACE.lg,
        borderRadius: RADIUS.pill,
        borderWidth: 1,
        borderColor: pressed ? colors.gold : colors.gold50,
        backgroundColor: pressed ? colors.surface2 : colors.surface,
        justifyContent: "center",
      })}
    >
      <AppText variant="small" weight="bold" color="gold">
        {label}
      </AppText>
    </Pressable>
  );
}

export interface ScreenHeaderProps {
  title?: string;
  /** Small gold line above the title («الاسم رقم 12», the door name…). */
  kicker?: string;
  /** Muted line(s) under the title. */
  subtitle?: string;
  /** Show the back pill (default true; tab roots pass false). */
  back?: boolean;
  fallbackHref?: Href;
  /** Actions on the end side of the back-pill row (favourite, share…). */
  actions?: ReactNode;
  children?: ReactNode;
}

export function ScreenHeader({ title, kicker, subtitle, back = true, fallbackHref, actions, children }: ScreenHeaderProps) {
  return (
    <View style={{ gap: SPACE.sm }}>
      {back || actions ? (
        <View style={{ flexDirection: "row", alignItems: "center", gap: SPACE.sm, marginBottom: SPACE.xs }}>
          {back ? <BackPill fallbackHref={fallbackHref} /> : null}
          <View style={{ flex: 1 }} />
          {actions ? <View style={{ flexDirection: "row", gap: SPACE.sm }}>{actions}</View> : null}
        </View>
      ) : null}
      {kicker ? (
        <AppText variant="small" color="gold">
          {kicker}
        </AppText>
      ) : null}
      {title ? (
        <AppText variant="h1" accessibilityRole="header">
          {title}
        </AppText>
      ) : null}
      {subtitle ? <AppText color="muted">{subtitle}</AppText> : null}
      {children}
    </View>
  );
}

export interface SectionTitleProps {
  title: string;
  /** Shows «المزيد ←» (or `moreLabel`) on the end side. */
  onMore?: () => void;
  moreHref?: Href;
  moreLabel?: string;
}

export function SectionTitle({ title, onMore, moreHref, moreLabel = "المزيد" }: SectionTitleProps) {
  const handle = onMore ?? (moreHref ? () => openHref(moreHref) : undefined);
  return (
    <View style={{ flexDirection: "row", alignItems: "center", gap: SPACE.md }}>
      <AppText variant="h2" accessibilityRole="header" style={{ flex: 1 }}>
        {title}
      </AppText>
      {handle ? (
        <Pressable onPress={handle} accessibilityRole="link" hitSlop={10} style={{ minHeight: TOUCH_MIN, justifyContent: "center" }}>
          <AppText variant="small" color="gold">
            {`${moreLabel} ←`}
          </AppText>
        </Pressable>
      ) : null}
    </View>
  );
}
