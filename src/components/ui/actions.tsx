/** FavoriteButton (♡/♥ via useFavorites), ShareButton (react-native Share), CopyButton (expo-clipboard). */
import * as Clipboard from "expo-clipboard";
import { useEffect, useState } from "react";
import { Pressable, Share, type StyleProp, type ViewStyle } from "react-native";

import { useFavorites } from "@/hooks/use-favorites";
import type { FavoriteRef } from "@/lib/favorites";
import { RADIUS, SPACE, TOUCH_MIN, useTheme } from "@/theme";

import { AppText } from "./app-text";

interface ActionPillProps {
  label: string;
  glyph?: string;
  onPress: () => void;
  active?: boolean;
  accessibilityLabel: string;
  style?: StyleProp<ViewStyle>;
}

/** Footer action pill of verse / hadith / sunnah cards («نسخ», «مشاركة», ♡). */
function ActionPill({ label, glyph, onPress, active, accessibilityLabel, style }: ActionPillProps) {
  const { colors } = useTheme();
  return (
    <Pressable
      onPress={onPress}
      accessibilityRole="button"
      accessibilityLabel={accessibilityLabel}
      accessibilityState={{ selected: !!active }}
      hitSlop={4}
      style={({ pressed }) => [
        {
          flexDirection: "row",
          alignItems: "center",
          gap: 6,
          minHeight: TOUCH_MIN - 4,
          paddingHorizontal: SPACE.md,
          borderRadius: RADIUS.pill,
          borderWidth: 1,
          borderColor: active || pressed ? colors.gold60 : colors.line,
          backgroundColor: pressed ? colors.surface2 : "transparent",
        },
        style,
      ]}
    >
      {glyph ? <AppText color="gold">{glyph}</AppText> : null}
      {label ? (
        <AppText variant="small" color="text">
          {label}
        </AppText>
      ) : null}
    </Pressable>
  );
}

export interface FavoriteButtonProps {
  /** e.g. { kind: "sunnah", id, fp, easy, stateId } — include stateId: it is the lookup hint for opening it later. */
  item: FavoriteRef;
  /** Show «حفظ / محفوظ» next to the heart (default: heart only). */
  showLabel?: boolean;
  style?: StyleProp<ViewStyle>;
}

export function FavoriteButton({ item, showLabel, style }: FavoriteButtonProps) {
  const { isSaved, toggle } = useFavorites();
  const saved = isSaved(item);
  return (
    <ActionPill
      glyph={saved ? "♥" : "♡"}
      label={showLabel ? (saved ? "محفوظ" : "حفظ") : ""}
      active={saved}
      onPress={() => toggle(item)}
      accessibilityLabel={saved ? "إزالة من محفوظاتي" : "إضافة إلى محفوظاتي"}
      style={style}
    />
  );
}

/** Temporary «تم» state for a second and a half after an action. */
function useFlash(): [boolean, () => void] {
  const [on, setOn] = useState(false);
  useEffect(() => {
    if (!on) return;
    const t = setTimeout(() => setOn(false), 1600);
    return () => clearTimeout(t);
  }, [on]);
  return [on, () => setOn(true)];
}

export interface CopyButtonProps {
  text: string;
  label?: string;
  style?: StyleProp<ViewStyle>;
}

export function CopyButton({ text, label = "نسخ", style }: CopyButtonProps) {
  const [done, flash] = useFlash();
  return (
    <ActionPill
      label={done ? "نُسخ ✓" : label}
      onPress={() => {
        Clipboard.setStringAsync(text).then(flash, () => undefined);
      }}
      accessibilityLabel={label}
      style={style}
    />
  );
}

export interface ShareButtonProps {
  message: string;
  title?: string;
  label?: string;
  style?: StyleProp<ViewStyle>;
}

/** Opens the system share sheet; where sharing is unavailable (some browsers) the text is copied instead. */
export function ShareButton({ message, title, label = "مشاركة", style }: ShareButtonProps) {
  const [copied, flash] = useFlash();
  const onPress = () => {
    Share.share(title ? { message, title } : { message }).catch(() => Clipboard.setStringAsync(message).then(flash, () => undefined));
  };
  return <ActionPill label={copied ? "نُسخ ✓" : label} onPress={onPress} accessibilityLabel={label} style={style} />;
}
