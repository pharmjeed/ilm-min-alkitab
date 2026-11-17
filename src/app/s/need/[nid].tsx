// Placeholder route (foundation). The screen owner replaces the body; keep the route file thin.
import { useLocalSearchParams } from "expo-router";
import { UnderConstruction } from "@/components/ui";

export default function NeedScreen() {
  const { nid } = useLocalSearchParams<{ nid?: string }>();
  return <UnderConstruction title="الحاجة" kicker={`الحاجة ${nid ?? ""}`} fallbackHref="/sunan" />;
}
