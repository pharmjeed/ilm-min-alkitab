/**
 * The app's content API (ARCHITECTURE §3). Screens use the hooks in src/hooks/use-data.ts; non-React
 * code (notifications, «اسم اليوم») can call these functions directly.
 */
import { onPacksChanged } from "./events";
import { packSource } from "./reader";
import { createPackStore } from "./store-core";

export const packStore = createPackStore(packSource);

// A sync switched versions: drop memoised data of those sections (keys are versioned anyway; this frees memory).
onPacksChanged((change) => packStore.clear(change.sections));

export const getNamesIndex = () => packStore.getNamesIndex();
export const getNameDetail = (id: number) => packStore.getNameDetail(id);
export const getSunanIndex = () => packStore.getSunanIndex();
export const getSunanChunkForState = (stateId: number) => packStore.getSunanChunkForState(stateId);
export const getStateItems = (stateId: number) => packStore.getStateItems(stateId);
export const getSunnahItem = (id: string, fp?: string | null, stateHint?: number | null) =>
  packStore.getSunnahItem(id, fp, stateHint);
export const getPackSources = () => packStore.getSources();

export { getDataEpoch, onPacksChanged, subscribeEpoch } from "./events";
export type { PacksChange } from "./events";
export { PackError, type StateItems } from "./store-core";
