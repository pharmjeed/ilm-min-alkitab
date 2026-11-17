import { AppText, Card, Pill, ScreenHeader, Screen } from "@/components/ui";

export default function NotFoundScreen() {
  return (
    <Screen>
      <ScreenHeader title="الصفحة غير موجودة" />
      <Card>
        <AppText color="muted">لعلّ الرابط قديم أو فيه خطأ.</AppText>
        <Pill label="إلى «يومي» ←" href="/" variant="outline" style={{ alignSelf: "flex-start" }} />
      </Card>
    </Screen>
  );
}
