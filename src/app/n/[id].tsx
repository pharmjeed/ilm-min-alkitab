// Placeholder route (foundation). The screen owner replaces the body; keep the route file thin.
import { useLocalSearchParams } from "expo-router";
import { UnderConstruction } from "@/components/ui";

export default function NameScreen() {
  const { id } = useLocalSearchParams<{ id?: string }>();
  return <UnderConstruction title="الاسم" kicker={`الاسم رقم ${id ?? ""}`} fallbackHref="/names" />;
}
