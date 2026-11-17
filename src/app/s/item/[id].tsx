// Placeholder route (foundation). The screen owner replaces the body; keep the route file thin.
// Params: id, fp (identity across versions), st (state hint) — build links with sunnahItemHref() from
// @/lib/links and load with useSunnahItem(paramStr(id), paramStr(fp), paramInt(st)).
import { useLocalSearchParams } from "expo-router";
import { UnderConstruction } from "@/components/ui";

export default function SunnahItemScreen() {
  const { id, fp, st } = useLocalSearchParams<{ id?: string; fp?: string; st?: string }>();
  const note = [fp ? `fp=${fp}` : "", st ? `st=${st}` : ""].filter(Boolean).join(" · ");
  return <UnderConstruction title="السنّة" kicker={`السنّة ${id ?? ""}`} fallbackHref="/sunan" note={note || undefined} />;
}
