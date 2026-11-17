// Placeholder route (foundation). The screen owner replaces the body; keep the route file thin.
import { useLocalSearchParams } from "expo-router";
import { UnderConstruction } from "@/components/ui";

export default function DoorScreen() {
  const { door } = useLocalSearchParams<{ door?: string }>();
  return <UnderConstruction title="أيُّ حالٍ أقرب إلى ما تعيشه؟" kicker={`الباب ${door ?? ""}`} fallbackHref="/names" />;
}
