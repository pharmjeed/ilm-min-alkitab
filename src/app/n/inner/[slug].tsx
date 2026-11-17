// Placeholder route (foundation). The screen owner replaces the body; keep the route file thin.
import { useLocalSearchParams } from "expo-router";
import { UnderConstruction } from "@/components/ui";

export default function InnerTypeScreen() {
  const { slug } = useLocalSearchParams<{ slug?: string }>();
  return <UnderConstruction title="ما بأنفسهم" kicker={slug ?? undefined} fallbackHref="/names" />;
}
