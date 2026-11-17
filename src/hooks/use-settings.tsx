/**
 * Settings context (theme, text size, morning reminder) persisted in AsyncStorage ("ilm.settings.v1").
 * `ready` is false until the stored value is read — the root layout keeps the splash until then.
 */
import AsyncStorage from "@react-native-async-storage/async-storage";
import { createContext, use, useCallback, useEffect, useMemo, useState, type ReactNode } from "react";

import {
  DEFAULT_SETTINGS,
  SETTINGS_KEY,
  mergeSettings,
  parseStoredSettings,
  type Settings,
  type SettingsPatch,
} from "@/lib/settings";

export interface SettingsContextValue {
  settings: Settings;
  ready: boolean;
  /** Partial update (morning is merged field by field); persisted immediately. */
  update: (patch: SettingsPatch) => void;
}

const SettingsContext = createContext<SettingsContextValue | null>(null);

export function SettingsProvider({ children }: { children: ReactNode }) {
  const [settings, setSettings] = useState<Settings>(DEFAULT_SETTINGS);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    let alive = true;
    AsyncStorage.getItem(SETTINGS_KEY)
      .then((raw) => {
        if (alive) setSettings(parseStoredSettings(raw));
      })
      .catch(() => undefined)
      .finally(() => {
        if (alive) setReady(true);
      });
    return () => {
      alive = false;
    };
  }, []);

  // Persist every change once the stored value has been read.
  useEffect(() => {
    if (ready) AsyncStorage.setItem(SETTINGS_KEY, JSON.stringify(settings)).catch(() => undefined);
  }, [settings, ready]);

  const update = useCallback((patch: SettingsPatch) => setSettings((cur) => mergeSettings(cur, patch)), []);

  const value = useMemo(() => ({ settings, ready, update }), [settings, ready, update]);
  return <SettingsContext value={value}>{children}</SettingsContext>;
}

export function useSettings(): SettingsContextValue {
  const ctx = use(SettingsContext);
  if (!ctx) throw new Error("useSettings must be used inside <SettingsProvider>");
  return ctx;
}
