/**
 * «محفوظاتي» context: favourites on the device (AsyncStorage "ilm.favorites.v1").
 *
 *   const { toggle, isSaved } = useFavorites();
 *   toggle({ kind: "name", id: 12 });
 *   isSaved({ kind: "verse", nameId: 12, s: 2, a: 255 });
 *   toggle({ kind: "sunnah", id: item.id, fp: item.fp, easy: item.easy, stateId: item.stateId });
 *   // opening a saved sunnah: useSunnahItem(fav.id, fav.fp, fav.stateId), then refreshSunnah(...) with the result
 */
import AsyncStorage from "@react-native-async-storage/async-storage";
import { createContext, use, useCallback, useEffect, useMemo, useState, type ReactNode } from "react";

import {
  EMPTY_FAVORITES,
  FAVORITES_KEY,
  isSaved as isSavedIn,
  parseStoredFavorites,
  refreshSunnah as refreshSunnahIn,
  toggleFavorite,
  type FavoriteRef,
  type Favorites,
} from "@/lib/favorites";

export interface FavoritesContextValue {
  favorites: Favorites;
  ready: boolean;
  toggle: (ref: FavoriteRef) => void;
  isSaved: (ref: FavoriteRef) => boolean;
  /** Keep a saved sunnah's id/easy/stateId current after it was re-resolved by fp. */
  refreshSunnah: (fp: string, id: string, easy: string, stateId?: number) => void;
}

const FavoritesContext = createContext<FavoritesContextValue | null>(null);

export function FavoritesProvider({ children }: { children: ReactNode }) {
  const [favorites, setFavorites] = useState<Favorites>(EMPTY_FAVORITES);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    let alive = true;
    AsyncStorage.getItem(FAVORITES_KEY)
      .then((raw) => {
        if (alive) setFavorites(parseStoredFavorites(raw));
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
    if (ready) AsyncStorage.setItem(FAVORITES_KEY, JSON.stringify(favorites)).catch(() => undefined);
  }, [favorites, ready]);

  const toggle = useCallback((ref: FavoriteRef) => setFavorites((cur) => toggleFavorite(cur, ref)), []);
  const refreshSunnah = useCallback(
    (fp: string, id: string, easy: string, stateId?: number) =>
      setFavorites((cur) => refreshSunnahIn(cur, fp, id, easy, stateId)),
    [],
  );
  const isSaved = useCallback((ref: FavoriteRef) => isSavedIn(favorites, ref), [favorites]);

  const value = useMemo(
    () => ({ favorites, ready, toggle, isSaved, refreshSunnah }),
    [favorites, ready, toggle, isSaved, refreshSunnah],
  );
  return <FavoritesContext value={value}>{children}</FavoritesContext>;
}

export function useFavorites(): FavoritesContextValue {
  const ctx = use(FavoritesContext);
  if (!ctx) throw new Error("useFavorites must be used inside <FavoritesProvider>");
  return ctx;
}
