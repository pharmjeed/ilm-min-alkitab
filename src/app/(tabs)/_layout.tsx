/**
 * Bottom tabs (JS Tabs — they follow the RTL layout direction): the first tab is on the right.
 * Order as the reader sees it from right to left: «يومي» «الأسماء» «السنن» «محفوظاتي» «المزيد».
 */
import Ionicons from "@expo/vector-icons/Ionicons";
import { Tabs, type BottomTabNavigationOptions } from "expo-router/js-tabs";
import type { ComponentProps } from "react";
import { useSafeAreaInsets } from "react-native-safe-area-context";

import { FAMILY, useTheme } from "@/theme";

type IconName = ComponentProps<typeof Ionicons>["name"];

type IconColor = ComponentProps<typeof Ionicons>["color"];

/**
 * The navigator's default bar is 49 px (UIKit), which leaves the label a 10 px box: Thmanyah's tall
 * metrics (≈15 px line box at 12 px) get clipped. Item = 5 padding + 28 icon + 18 label + 5 padding = 56.
 * The bottom safe-area inset is added on top (the navigator keeps paddingBottom = inset).
 */
const TAB_BAR_HEIGHT = 60;
const LABEL_SIZE = 12;
const LABEL_LINE_HEIGHT = 18;

const icon =
  (active: IconName, inactive: IconName): BottomTabNavigationOptions["tabBarIcon"] =>
  function TabBarIcon({ color, size, focused }) {
    return <Ionicons name={focused ? active : inactive} size={size} color={color as IconColor} />;
  };

export default function TabsLayout() {
  const { colors } = useTheme();
  const insets = useSafeAreaInsets();
  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        tabBarActiveTintColor: colors.gold,
        tabBarInactiveTintColor: colors.muted,
        tabBarStyle: {
          backgroundColor: colors.bg,
          borderTopColor: colors.line,
          borderTopWidth: 1,
          height: TAB_BAR_HEIGHT + insets.bottom,
        },
        tabBarLabelStyle: { fontFamily: FAMILY.bodyMedium, fontSize: LABEL_SIZE, lineHeight: LABEL_LINE_HEIGHT },
        tabBarAllowFontScaling: false,
        sceneStyle: { backgroundColor: colors.bg },
      }}
    >
      <Tabs.Screen name="index" options={{ title: "يومي", tabBarIcon: icon("sunny", "sunny-outline") }} />
      <Tabs.Screen name="names" options={{ title: "الأسماء", tabBarIcon: icon("book", "book-outline") }} />
      <Tabs.Screen name="sunan" options={{ title: "السنن", tabBarIcon: icon("leaf", "leaf-outline") }} />
      <Tabs.Screen name="saved" options={{ title: "محفوظاتي", tabBarIcon: icon("heart", "heart-outline") }} />
      <Tabs.Screen name="more" options={{ title: "المزيد", tabBarIcon: icon("menu", "menu-outline") }} />
    </Tabs>
  );
}
