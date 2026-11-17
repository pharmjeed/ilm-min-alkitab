/**
 * Hijri (Umm al-Qura) and Gregorian date lines for «يومي». Pure TS.
 *
 * Hermes implements Intl.DateTimeFormat with the platform calendars (ICU on Android, NSCalendar on iOS),
 * but support can differ per device, so we check `resolvedOptions().calendar` and fall back to showing
 * only the Gregorian date. Digits are always Western (0–9), as on the platform; we also convert any
 * Arabic-Indic digits ourselves because `-u-nu-latn` is ignored on some engines.
 */
import { asciiDigits } from "./arabic/normalize";

const HIJRI_LOCALE = "ar-SA-u-ca-islamic-umalqura-nu-latn";
const GREGORIAN_LOCALE = "ar-u-ca-gregory-nu-latn";
const DATE_OPTS: Intl.DateTimeFormatOptions = { day: "numeric", month: "long", year: "numeric" };

export type FormatterFactory = (locale: string, opts: Intl.DateTimeFormatOptions) => Intl.DateTimeFormat;

const defaultFactory: FormatterFactory = (locale, opts) => new Intl.DateTimeFormat(locale, opts);

const GREGORIAN_MONTHS = [
  "يناير",
  "فبراير",
  "مارس",
  "أبريل",
  "مايو",
  "يونيو",
  "يوليو",
  "أغسطس",
  "سبتمبر",
  "أكتوبر",
  "نوفمبر",
  "ديسمبر",
];
const WEEKDAYS = ["الأحد", "الإثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة", "السبت"];

/** Remove bidi control marks some ICU builds insert, convert digits to 0–9. */
function clean(s: string): string {
  return asciiDigits(s.replace(/[\u200e\u200f\u061c]/g, "")).trim();
}

/** True when the engine really formats with the Umm al-Qura calendar. */
export function hasHijriSupport(make: FormatterFactory = defaultFactory): boolean {
  try {
    return make(HIJRI_LOCALE, DATE_OPTS).resolvedOptions().calendar === "islamic-umalqura";
  } catch {
    return false;
  }
}

/** «7 جمادى الآخرة 1448 هـ», or null when the calendar is unavailable. */
export function formatHijri(date: Date, make: FormatterFactory = defaultFactory): string | null {
  try {
    const f = make(HIJRI_LOCALE, DATE_OPTS);
    if (f.resolvedOptions().calendar !== "islamic-umalqura") return null;
    return clean(f.format(date));
  } catch {
    return null;
  }
}

/** «17 نوفمبر 2026» (local time), with a manual fallback when Intl is missing. */
export function formatGregorian(date: Date, make: FormatterFactory = defaultFactory): string {
  try {
    const f = make(GREGORIAN_LOCALE, DATE_OPTS);
    const cal = f.resolvedOptions().calendar;
    if (cal === "gregory" || cal === "iso8601") return clean(f.format(date));
  } catch {
    // fall through
  }
  return `${date.getDate()} ${GREGORIAN_MONTHS[date.getMonth()]} ${date.getFullYear()}`;
}

/** «الثلاثاء» (local time). */
export function weekdayAr(date: Date): string {
  return WEEKDAYS[date.getDay()]!;
}

export interface DateLines {
  weekday: string;
  hijri: string | null;
  gregorian: string;
}

export function dateLines(date: Date = new Date(), make: FormatterFactory = defaultFactory): DateLines {
  return { weekday: weekdayAr(date), hijri: formatHijri(date, make), gregorian: formatGregorian(date, make) };
}
