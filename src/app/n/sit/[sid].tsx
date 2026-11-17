// Placeholder route (foundation). The screen owner replaces the body; keep the route file thin.
import { useLocalSearchParams } from "expo-router";
import { UnderConstruction } from "@/components/ui";

export default function SituationScreen() {
  const { sid } = useLocalSearchParams<{ sid?: string }>();
  return <UnderConstruction title="ادعُ الله بهذه الأسماء" kicker={`الحال ${sid ?? ""}`} fallbackHref="/names" />;
}
