/** EmptyState, LoadingState («جارٍ التحميل…» with pulsing skeleton blocks), ErrorState. */
import { useEffect, useState } from "react";
import { Animated, Platform, View } from "react-native";

import { RADIUS, SPACE, useTheme } from "@/theme";

import { AppText } from "./app-text";
import { Card } from "./card";
import { Pill } from "./pills";

export interface EmptyStateProps {
  message: string;
  title?: string;
  action?: { label: string; onPress: () => void };
}

export function EmptyState({ message, title, action }: EmptyStateProps) {
  return (
    <View style={{ alignItems: "center", gap: SPACE.md, paddingVertical: SPACE.xxl, paddingHorizontal: SPACE.lg }}>
      {title ? (
        <AppText variant="h3" center>
          {title}
        </AppText>
      ) : null}
      <AppText color="muted" center>
        {message}
      </AppText>
      {action ? <Pill label={action.label} onPress={action.onPress} variant="outline" /> : null}
    </View>
  );
}

export interface LoadingStateProps {
  label?: string;
  /** Number of skeleton blocks (default 3). */
  blocks?: number;
}

export function LoadingState({ label = "جارٍ التحميل…", blocks = 3 }: LoadingStateProps) {
  const { colors } = useTheme();
  const [pulse] = useState(() => new Animated.Value(0.45));
  useEffect(() => {
    const native = Platform.OS !== "web";
    const loop = Animated.loop(
      Animated.sequence([
        Animated.timing(pulse, { toValue: 1, duration: 700, useNativeDriver: native }),
        Animated.timing(pulse, { toValue: 0.45, duration: 700, useNativeDriver: native }),
      ]),
    );
    loop.start();
    return () => loop.stop();
  }, [pulse]);
  return (
    <View accessibilityRole="progressbar" accessibilityLabel={label} style={{ gap: SPACE.md, paddingVertical: SPACE.lg }}>
      {Array.from({ length: blocks }, (_, i) => (
        <Animated.View
          key={i}
          style={{
            opacity: pulse,
            height: i === 0 ? 28 : 72,
            width: i === 0 ? "55%" : "100%",
            borderRadius: RADIUS.card,
            backgroundColor: colors.skeleton,
          }}
        />
      ))}
      <AppText variant="small" color="muted" center>
        {label}
      </AppText>
    </View>
  );
}

export interface ErrorStateProps {
  message?: string;
  /** Technical detail (not shown to readers in production builds). */
  detail?: string;
  onRetry?: () => void;
}

export function ErrorState({ message = "تعذّر تحميل المحتوى.", detail, onRetry }: ErrorStateProps) {
  const { colors } = useTheme();
  return (
    <Card style={{ borderColor: colors.error, alignItems: "stretch" }} gap={SPACE.md}>
      <AppText color="error" weight="medium">
        {message}
      </AppText>
      {__DEV__ && detail ? (
        <AppText variant="caption" selectable>
          {detail}
        </AppText>
      ) : null}
      {onRetry ? <Pill label="إعادة المحاولة" onPress={onRetry} variant="outline" size="sm" style={{ alignSelf: "flex-start" }} /> : null}
    </Card>
  );
}
