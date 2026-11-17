/**
 * Root layout: providers (safe area → settings → favourites → theme), fonts + splash, RTL root,
 * the Stack (no native headers — every screen renders its own ScreenHeader), notification-tap routing
 * and the background content sync after the first render.
 */
import { useFonts } from "expo-font";
import { DarkTheme, DefaultTheme, LocaleProvider, Stack, ThemeProvider as NavigationThemeProvider, type Theme } from "expo-router";
import * as SplashScreen from "expo-splash-screen";
import { StatusBar } from "expo-status-bar";
import * as SystemUI from "expo-system-ui";
import { useEffect, useMemo } from "react";
import { Platform, View } from "react-native";
import { SafeAreaProvider } from "react-native-safe-area-context";

import { FavoritesProvider, useFavorites } from "@/hooks/use-favorites";
import { useNotificationRouting } from "@/hooks/use-notification-routing";
import { SettingsProvider, useSettings } from "@/hooks/use-settings";
import { syncPacks } from "@/lib/packs/sync";
import { FAMILY, FONT_FILES, STATUS_BAR, ThemeProvider, useTheme } from "@/theme";

SplashScreen.preventAutoHideAsync().catch(() => undefined);

/** Delay before the first content check, so it never competes with the first screen. */
const SYNC_DELAY_MS = 2500;

export default function RootLayout() {
  const [fontsLoaded, fontError] = useFonts(FONT_FILES);
  return (
    <SafeAreaProvider>
      <SettingsProvider>
        <FavoritesProvider>
          <ThemeProvider>
            <AppShell fontsReady={fontsLoaded || fontError != null} />
          </ThemeProvider>
        </FavoritesProvider>
      </SettingsProvider>
    </SafeAreaProvider>
  );
}

function AppShell({ fontsReady }: { fontsReady: boolean }) {
  const { ready: settingsReady } = useSettings();
  const { ready: favoritesReady } = useFavorites();
  const { scheme, colors } = useTheme();
  const ready = fontsReady && settingsReady && favoritesReady;

  useEffect(() => {
    if (ready) SplashScreen.hideAsync().catch(() => undefined);
  }, [ready]);

  // Window background behind screens (avoids white flashes during transitions / keyboard).
  useEffect(() => {
    SystemUI.setBackgroundColorAsync(colors.bg).catch(() => undefined);
    if (Platform.OS === "web" && typeof document !== "undefined") {
      document.documentElement.setAttribute("dir", "rtl");
      document.documentElement.setAttribute("lang", "ar");
      document.body.style.backgroundColor = colors.bg;
    }
  }, [colors.bg]);

  useNotificationRouting(ready);
  useStartupSync(ready);

  const navigationTheme = useMemo<Theme>(() => {
    const base = scheme === "dark" ? DarkTheme : DefaultTheme;
    return {
      ...base,
      dark: scheme === "dark",
      colors: {
        ...base.colors,
        primary: colors.gold,
        background: colors.bg,
        card: colors.bg,
        text: colors.text,
        border: colors.line,
        notification: colors.gold,
      },
      fonts: {
        regular: { fontFamily: FAMILY.bodyRegular, fontWeight: "normal" },
        medium: { fontFamily: FAMILY.bodyMedium, fontWeight: "normal" },
        bold: { fontFamily: FAMILY.bodyBold, fontWeight: "normal" },
        heavy: { fontFamily: FAMILY.bodyBold, fontWeight: "normal" },
      },
    };
  }, [scheme, colors]);

  if (!ready) return null; // the native splash stays up until fonts and stored settings are ready

  return (
    <NavigationThemeProvider value={navigationTheme}>
      <LocaleProvider direction="rtl">
        <View style={{ flex: 1, direction: "rtl", backgroundColor: colors.bg }}>
          <StatusBar style={STATUS_BAR[scheme]} />
          <Stack screenOptions={{ headerShown: false, contentStyle: { backgroundColor: colors.bg } }} />
        </View>
      </LocaleProvider>
    </NavigationThemeProvider>
  );
}

/** Check the platform for newer content once, shortly after the first screen is shown. */
function useStartupSync(ready: boolean) {
  useEffect(() => {
    if (!ready) return;
    const t = setTimeout(() => {
      void syncPacks();
    }, SYNC_DELAY_MS);
    return () => clearTimeout(t);
  }, [ready]);
}
