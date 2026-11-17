// Placeholder route (foundation). The screen owner replaces the body; keep the route file thin.
import { useLocalSearchParams } from "expo-router";
import { UnderConstruction } from "@/components/ui";

export default function NameInSituationScreen() {
  const { sid, id } = useLocalSearchParams<{ sid?: string; id?: string }>();
  return <UnderConstruction title="الاسم في هذا الموقف" kicker={`الحال ${sid ?? ""} · الاسم ${id ?? ""}`} fallbackHref="/names" />;
}
