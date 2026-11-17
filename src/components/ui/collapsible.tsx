/**
 * Collapsible — two modes:
 *  - toggle (default): the children are hidden until opened («إظهار الآية السابقة ▾ / إخفاء … ▴»);
 *  - clip (`collapsedHeight`): the children are cut at that height and the toggle «إظهار المزيد ▾ /
 *    إظهار أقل ▴» appears only when they are taller (e.g. a hadith folded after ~6 lines:
 *    collapsedHeight = 6 * lineHeight).
 */
import { useState, type ReactNode } from "react";
import { Pressable, View } from "react-native";

import { SPACE, TOUCH_MIN } from "@/theme";

import { AppText } from "./app-text";

export interface CollapsibleProps {
  children: ReactNode;
  collapsedHeight?: number;
  initiallyOpen?: boolean;
  /** Label while closed (default «إظهار المزيد»); «▾» is appended. */
  moreLabel?: string;
  /** Label while open (default «إظهار أقل»); «▴» is appended. */
  lessLabel?: string;
}

export function Collapsible({ children, collapsedHeight, initiallyOpen = false, moreLabel = "إظهار المزيد", lessLabel = "إظهار أقل" }: CollapsibleProps) {
  const [open, setOpen] = useState(initiallyOpen);
  const [fullHeight, setFullHeight] = useState(0);
  const clip = collapsedHeight != null;
  const needsToggle = !clip || fullHeight > collapsedHeight + 4;

  const toggle = needsToggle ? (
    <Pressable
      onPress={() => setOpen((o) => !o)}
      accessibilityRole="button"
      accessibilityState={{ expanded: open }}
      hitSlop={8}
      style={{ alignSelf: "flex-start", minHeight: TOUCH_MIN, justifyContent: "center" }}
    >
      <AppText variant="small" color="gold">
        {open ? `${lessLabel} ▴` : `${moreLabel} ▾`}
      </AppText>
    </Pressable>
  ) : null;

  if (!clip) {
    return (
      <View style={{ gap: SPACE.xs }}>
        {toggle}
        {open ? children : null}
      </View>
    );
  }
  return (
    <View style={{ gap: SPACE.xs }}>
      <View style={{ maxHeight: open ? undefined : collapsedHeight, overflow: "hidden" }}>
        <View style={{ flexShrink: 0 }} onLayout={(e) => setFullHeight(e.nativeEvent.layout.height)}>
          {children}
        </View>
      </View>
      {toggle}
    </View>
  );
}
