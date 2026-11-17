// Placeholder route (foundation). The screen owner replaces the body; keep the route file thin.
import { useLocalSearchParams } from "expo-router";
import { UnderConstruction } from "@/components/ui";

export default function StateScreen() {
  const { stid } = useLocalSearchParams<{ stid?: string }>();
  return <UnderConstruction title="الحال" kicker={`الحال ${stid ?? ""}`} fallbackHref="/sunan" />;
}
