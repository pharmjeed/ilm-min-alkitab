/** Placeholder body for routes whose screens are not built yet (screen owners replace it). */
import type { Href } from "expo-router";

import { AppText } from "./app-text";
import { Card } from "./card";
import { ScreenHeader } from "./header";
import { Screen } from "./screen";

export interface UnderConstructionProps {
  title: string;
  kicker?: string;
  /** Tab roots: no back pill, tab safe-area. */
  tab?: boolean;
  fallbackHref?: Href;
  /** Debug line (route params). */
  note?: string;
}

export function UnderConstruction({ title, kicker, tab, fallbackHref, note }: UnderConstructionProps) {
  return (
    <Screen inTabs={tab}>
      <ScreenHeader title={title} kicker={kicker} back={!tab} fallbackHref={fallbackHref} />
      <Card tone="notice">
        <AppText color="gold" weight="medium">
          قيد البناء
        </AppText>
        {note ? <AppText variant="caption">{note}</AppText> : null}
      </Card>
    </Screen>
  );
}
