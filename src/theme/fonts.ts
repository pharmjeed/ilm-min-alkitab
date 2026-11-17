/**
 * THE one place for font families. Components never name a font file or family directly: they use a
 * role (body / display / scripture) and a weight, resolved by `fontFamily()`.
 *
 * Each face is registered as its own family name (e.g. "ThmanyahSans-Bold") and `fontWeight` is NOT
 * set alongside it — the reliable way on Android (a family + weight that does not exist falls back to
 * the system font).
 *
 * LICENCE — OPEN QUESTION: the Thmanyah fonts (Thmanyah Sans, Thmanyah Serif Display) are used by the
 * platform as web fonts; their licence text (platform: public/fonts/LICENSE-Thmanyah.txt) forbids
 * redistributing the font files. Embedding them in an app binary is NOT cleared yet — the owner must
 * confirm with font.thmanyah.com before a store release. Fallback: IBM Plex Sans Arabic (SIL OFL) —
 * replace the files in FONT_FILES (keep the family keys or change FAMILY below) and nothing else changes.
 * Amiri (Quran & hadith only) is SIL OFL (assets/fonts/OFL-Amiri.txt).
 */

export type FontRole = "body" | "display" | "scripture";
export type FontWeight = "regular" | "medium" | "bold";

export const FAMILY = {
  bodyRegular: "ThmanyahSans-Regular",
  bodyMedium: "ThmanyahSans-Medium",
  bodyBold: "ThmanyahSans-Bold",
  displayMedium: "ThmanyahSerifDisplay-Medium",
  displayBold: "ThmanyahSerifDisplay-Bold",
  scriptureRegular: "Amiri-Regular",
  scriptureBold: "Amiri-Bold",
} as const;

/** Map for `useFonts()` (runtime loading — works in Expo Go, builds and web). */
export const FONT_FILES = {
  [FAMILY.bodyRegular]: require("../../assets/fonts/thmanyahsans-Regular.otf"),
  [FAMILY.bodyMedium]: require("../../assets/fonts/thmanyahsans-Medium.otf"),
  [FAMILY.bodyBold]: require("../../assets/fonts/thmanyahsans-Bold.otf"),
  [FAMILY.displayMedium]: require("../../assets/fonts/thmanyahserifdisplay-Medium.otf"),
  [FAMILY.displayBold]: require("../../assets/fonts/thmanyahserifdisplay-Bold.otf"),
  [FAMILY.scriptureRegular]: require("../../assets/fonts/Amiri-Regular.ttf"),
  [FAMILY.scriptureBold]: require("../../assets/fonts/Amiri-Bold.ttf"),
} as const;

/**
 * The family for a role + weight. Display headings are Medium by default (website h1–h4 weight 500);
 * scripture has Regular and Bold only.
 */
export function fontFamily(role: FontRole, weight: FontWeight = "regular"): string {
  switch (role) {
    case "display":
      return weight === "bold" ? FAMILY.displayBold : FAMILY.displayMedium;
    case "scripture":
      return weight === "bold" ? FAMILY.scriptureBold : FAMILY.scriptureRegular;
    default:
      return weight === "bold" ? FAMILY.bodyBold : weight === "medium" ? FAMILY.bodyMedium : FAMILY.bodyRegular;
  }
}
