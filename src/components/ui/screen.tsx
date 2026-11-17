/**
 * Screen — page container: safe area, theme background, page padding 16, optional scroll.
 * Tab screens pass `inTabs` (the tab bar handles the bottom inset).
 * List screens with a FlatList pass `scroll={false}` and render the list as the child.
 */
import type { ReactNode } from "react";
import { ScrollView, View, type StyleProp, type ViewStyle } from "react-native";
import { SafeAreaView, type Edge } from "react-native-safe-area-context";

import { PAGE_PADDING, SPACE, useTheme } from "@/theme";

/** Content column width on tablets / web. */
export const MAX_CONTENT_WIDTH = 720;

export interface ScreenProps {
  children: ReactNode;
  scroll?: boolean;
  inTabs?: boolean;
  /** Vertical gap between direct children (default 16). */
  gap?: number;
  contentStyle?: StyleProp<ViewStyle>;
}

export function Screen({ children, scroll = true, inTabs, gap = SPACE.lg, contentStyle }: ScreenProps) {
  const { colors } = useTheme();
  const edges: Edge[] = inTabs ? ["top"] : ["top", "bottom"];
  const column: ViewStyle = {
    width: "100%",
    maxWidth: MAX_CONTENT_WIDTH,
    alignSelf: "center",
    paddingHorizontal: PAGE_PADDING,
    paddingTop: SPACE.lg,
    paddingBottom: SPACE.xxl,
    gap,
  };
  return (
    <SafeAreaView edges={edges} style={{ flex: 1, backgroundColor: colors.bg }}>
      {scroll ? (
        <ScrollView
          style={{ flex: 1 }}
          contentContainerStyle={[column, contentStyle]}
          keyboardShouldPersistTaps="handled"
          keyboardDismissMode="on-drag"
        >
          {children}
        </ScrollView>
      ) : (
        <View style={[column, { flex: 1, paddingBottom: 0 }, contentStyle]}>{children}</View>
      )}
    </SafeAreaView>
  );
}
