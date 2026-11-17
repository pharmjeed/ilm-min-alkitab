import { isLoaded } from "expo-font";
import type { StyleProp, ViewStyle } from "react-native";
import { Text, View } from "react-native";

import { BRAND_COLORS, LogoMark } from "./LogoMark";

export const APP_TITLE = "علم من الكتاب";

/** Heading face preferred for the lockup when the theme has loaded it under this name. */
const PREFERRED_FONT = "ThmanyahSerif-Bold";

export type LogoLockupProps = {
  /** Mark size in px. Default 36 (as in the platform header). */
  size?: number;
  /** Mark colour. Default: dark-theme gold. */
  color?: string;
  /** Title colour. Default: dark-theme cream. */
  textColor?: string;
  /**
   * Title font family — pass the theme's heading face. If omitted, "ThmanyahSerif-Bold" is used
   * only if it is already loaded when this renders: `isLoaded` is re-read on every render, but
   * nothing re-renders the lockup when a runtime `useFonts` finishes later (and with the React
   * Compiler a parent with unchanged props will not re-render it either). So either pass this
   * prop, or keep the splash up in the root layout until `useFonts` resolves.
   */
  fontFamily?: string;
  /** Title size in px. Default: 0.6 × size. */
  fontSize?: number;
  title?: string;
  style?: StyleProp<ViewStyle>;
};

/** Mark + «علم من الكتاب». In an RTL layout the mark sits at the start (right edge). */
export function LogoLockup({
  size = 36,
  color = BRAND_COLORS.dark.mark,
  textColor = BRAND_COLORS.dark.text,
  fontFamily,
  fontSize,
  title = APP_TITLE,
  style,
}: LogoLockupProps) {
  const family = fontFamily ?? (isLoaded(PREFERRED_FONT) ? PREFERRED_FONT : undefined);
  const titleSize = fontSize ?? Math.round(size * 0.6);

  return (
    <View
      style={[{ flexDirection: "row", alignItems: "center", gap: Math.round(size * 0.3) }, style]}
      accessible
      aria-label={title}
    >
      <LogoMark size={size} color={color} decorative />
      <Text
        numberOfLines={1}
        maxFontSizeMultiplier={1.2}
        style={{ color: textColor, fontFamily: family, fontSize: titleSize, writingDirection: "rtl" }}
      >
        {title}
      </Text>
    </View>
  );
}
