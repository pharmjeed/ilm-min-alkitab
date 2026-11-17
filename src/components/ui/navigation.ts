import { router, type Href } from "expo-router";

/** Go back when there is history (in-app or a deep link opened mid-stack), else replace with `fallback`. */
export function goBack(fallback: Href = "/") {
  if (router.canGoBack()) router.back();
  else router.replace(fallback);
}

/** Open an in-app route. */
export function openHref(href: Href) {
  router.push(href);
}
