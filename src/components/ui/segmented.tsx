/**
 * Segmented — a row of pills where one is active (website NameTabs: active = gold fill, bg-coloured text).
 * Pills wrap onto several lines instead of scrolling horizontally (horizontal scrolling in RTL behaves
 * differently across runtimes).
 */
import { Pressable, View, type StyleProp, type ViewStyle } from "react-native";

import { RADIUS, SPACE, TOUCH_MIN, useTheme } from "@/theme";

import { AppText } from "./app-text";

export interface SegmentOption<K extends string> {
  key: K;
  label: string;
  /** Shown after the label in small digits («الآيات 12»). */
  count?: number;
}

export interface SegmentedProps<K extends string> {
  options: readonly SegmentOption<K>[];
  value: K;
  onChange: (key: K) => void;
  accessibilityLabel?: string;
  style?: StyleProp<ViewStyle>;
}

export function Segmented<K extends string>({ options, value, onChange, accessibilityLabel, style }: SegmentedProps<K>) {
  const { colors } = useTheme();
  return (
    <View accessibilityRole="tablist" accessibilityLabel={accessibilityLabel} style={[{ flexDirection: "row", flexWrap: "wrap", gap: SPACE.sm }, style]}>
      {options.map((o) => {
        const active = o.key === value;
        return (
          <Pressable
            key={o.key}
            onPress={() => onChange(o.key)}
            accessibilityRole="tab"
            accessibilityState={{ selected: active }}
            style={({ pressed }) => ({
              flexDirection: "row",
              alignItems: "center",
              gap: 6,
              minHeight: TOUCH_MIN - 4,
              paddingHorizontal: SPACE.lg,
              borderRadius: RADIUS.pill,
              borderWidth: 1,
              borderColor: active ? colors.gold : pressed ? colors.gold60 : colors.line,
              backgroundColor: active ? colors.gold : pressed ? colors.surface2 : colors.surface,
            })}
          >
            <AppText variant="small" weight="medium" color={active ? "onGold" : "text"}>
              {o.label}
            </AppText>
            {o.count != null ? (
              <AppText variant="caption" color={active ? "onGold" : "gold"} tabular>
                {o.count.toLocaleString("en-US")}
              </AppText>
            ) : null}
          </Pressable>
        );
      })}
    </View>
  );
}
