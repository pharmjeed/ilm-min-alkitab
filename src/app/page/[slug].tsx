// Placeholder route (foundation). The screen owner replaces the body; keep the route file thin.
import { useLocalSearchParams } from "expo-router";
import { UnderConstruction } from "@/components/ui";

export default function PageScreen() {
  const { slug } = useLocalSearchParams<{ slug?: string }>();
  return <UnderConstruction title="صفحة" kicker={slug ?? undefined} fallbackHref="/more" />;
}
