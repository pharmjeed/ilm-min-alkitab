import type { StyleProp, ViewStyle } from "react-native";
import { View } from "react-native";
import Svg, { Circle, G, Polygon } from "react-native-svg";

/**
 * Brand mark of «علم من الكتاب»: the eight-pointed «ربع الحزب» star (two equal squares at 0° and
 * 45° sharing a centre), a thin inner ring and a centre dot. Same geometry as
 * `assets/brand/mark.svg` (120-unit box) — keep both in sync (see `assets/brand/README.md`).
 */

export const BRAND_COLORS = {
  dark: { mark: "#D4A449", text: "#F7ECD6", bg: "#0D1F1F" },
  light: { mark: "#846008", text: "#0D1F1F", bg: "#F5E9D0" },
} as const;

type MarkGeometry = {
  /** axis-aligned square (corners on the diagonals) */
  sq0: string;
  /** the same square turned 45° (corners on the axes) */
  sq45: string;
  stroke: number;
  ringR: number;
  ringStroke: number;
  ringOpacity: number;
  dotR: number;
};

/** Full mark: `assets/brand/mark.svg`. */
const FULL: MarkGeometry = {
  sq0: "95.36,24.64 95.36,95.36 24.64,95.36 24.64,24.64",
  sq45: "110,60 60,110 10,60 60,10",
  stroke: 6,
  ringR: 16,
  ringStroke: 3.25,
  ringOpacity: 0.85,
  dotR: 5,
};

/** Small-size mark (no ring, heavier stroke): `assets/brand/mark-compact.svg`. */
const COMPACT: MarkGeometry = {
  sq0: "96.77,23.23 96.77,96.77 23.23,96.77 23.23,23.23",
  sq45: "112,60 60,112 8,60 60,8",
  stroke: 8.5,
  ringR: 0,
  ringStroke: 0,
  ringOpacity: 0,
  dotR: 7.5,
};

/** Below this size (dp) `variant="auto"` draws the compact mark (no ring, heavier stroke). */
export const LOGO_COMPACT_BELOW = 28;

export type LogoMarkProps = {
  /** Width and height in px. Default 36. */
  size?: number;
  /** Mark colour. Default: dark-theme gold. Pass the theme's gold in light mode (#846008). */
  color?: string;
  /** "auto" (default) = compact under 28 dp, full otherwise. */
  variant?: "auto" | "full" | "compact";
  /** Decorative use (e.g. a hero watermark): hidden from screen readers. */
  decorative?: boolean;
  /** Spoken label when not decorative. */
  label?: string;
  style?: StyleProp<ViewStyle>;
};

export function LogoMark({
  size = 36,
  color = BRAND_COLORS.dark.mark,
  variant = "auto",
  decorative = false,
  label = "شعار علم من الكتاب",
  style,
}: LogoMarkProps) {
  const compact = variant === "compact" || (variant === "auto" && size < LOGO_COMPACT_BELOW);
  const g = compact ? COMPACT : FULL;

  return (
    <View
      style={[{ width: size, height: size, pointerEvents: "none" }, style]}
      // iOS only exposes a View to VoiceOver (and reads its label) when it is `accessible`.
      accessible={!decorative}
      role={decorative ? undefined : "img"}
      aria-label={decorative ? undefined : label}
      aria-hidden={decorative}
    >
      <Svg width={size} height={size} viewBox="0 0 120 120">
        <G fill="none" stroke={color} strokeWidth={g.stroke} strokeLinejoin="miter" strokeMiterlimit={4}>
          <Polygon points={g.sq0} />
          <Polygon points={g.sq45} />
          {g.ringR > 0 ? (
            <Circle cx={60} cy={60} r={g.ringR} strokeWidth={g.ringStroke} strokeOpacity={g.ringOpacity} />
          ) : null}
        </G>
        <Circle cx={60} cy={60} r={g.dotR} fill={color} />
      </Svg>
    </View>
  );
}
