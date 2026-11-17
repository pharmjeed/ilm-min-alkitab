/**
 * App-wide constants. No secrets here (and never any key in the app): the app only calls the
 * platform's public endpoints. Pure TS.
 */

export const APP_NAME = "علم من الكتاب";

/** The platform (Next.js on Vercel). */
export const API_BASE = "https://asma-platform-nine.vercel.app";

/** «اسأل عن موقفك» instant matcher: POST {question} (3–600 chars). */
export const ASK_INSTANT_URL = `${API_BASE}/api/ask/instant`;

/** Public website pages (for «عن المنصة», sharing links). */
export const SITE_URL = API_BASE;

/** dorar hadith link. */
export const dorarUrl = (code: string) => `https://dorar.net/h/${encodeURIComponent(code)}`;
