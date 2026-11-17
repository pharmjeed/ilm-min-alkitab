// Placeholder route (foundation). The screen owner replaces the body; keep the route file thin.
import { useLocalSearchParams } from "expo-router";
import { UnderConstruction } from "@/components/ui";

export default function DomainScreen() {
  const { did } = useLocalSearchParams<{ did?: string }>();
  return <UnderConstruction title="ماذا تحتاج؟" kicker={`المجال ${did ?? ""}`} fallbackHref="/sunan" />;
}
