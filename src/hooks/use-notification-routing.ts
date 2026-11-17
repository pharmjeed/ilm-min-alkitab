/**
 * Opens the route carried by a tapped reminder (`data.url`, e.g. "/n/12"), also when the tap launched the
 * app (getLastNotificationResponse). Web: see ./use-notification-routing.web.ts (no-op, so web never
 * loads expo-notifications).
 */
import * as Notifications from "expo-notifications";
import { router, type Href } from "expo-router";
import { useEffect } from "react";

function open(response: Notifications.NotificationResponse | null) {
  const url = response?.notification.request.content.data?.url;
  if (typeof url === "string" && url.startsWith("/")) router.push(url as Href);
}

/** Call from the root layout once the navigator is mounted (`ready`). */
export function useNotificationRouting(ready: boolean) {
  useEffect(() => {
    if (!ready) return;
    const last = Notifications.getLastNotificationResponse();
    if (last) {
      open(last);
      Notifications.clearLastNotificationResponse();
    }
    const sub = Notifications.addNotificationResponseReceivedListener(open);
    return () => sub.remove();
  }, [ready]);
}
