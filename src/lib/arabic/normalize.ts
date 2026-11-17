/**
 * Arabic normalization — MUST stay byte-for-byte equivalent to `normalize()` in
 * scripts/excel_to_json.py (the reference parser). Also provides helpers that
 * mimic Python string semantics (str.strip / str.split / re \s) so the TS
 * parser produces exactly the same output as the Python one.
 */

/** Characters Python's `str.isspace()` / `re \s` (str pattern) treat as whitespace. */
export const PY_WS_CHARS =
  "\\t\\n\\x0b\\x0c\\r\\x1c\\x1d\\x1e\\x1f \\x85\\xa0\\u1680\\u2000-\\u200a\\u2028\\u2029\\u202f\\u205f\\u3000";
/** Regex fragment equivalent to Python's `\s` (use inside `new RegExp`). */
export const WS = `[${PY_WS_CHARS}]`;
/** Regex fragment equivalent to Python's `\d` for the digits we may meet (ASCII + Arabic-Indic). */
export const DIGIT = "[0-9\\u0660-\\u0669\\u06f0-\\u06f9]";

const WS_RUN = new RegExp(`${WS}+`, "g");
const WS_LEAD = new RegExp(`^${WS}+`);
const WS_TRAIL = new RegExp(`${WS}+$`);

/** Python `str.strip()` (no args). */
export function pyStrip(s: string): string {
  return s.replace(WS_LEAD, "").replace(WS_TRAIL, "");
}

/** Python `str.split()` (no args): split on whitespace runs, drop empties. */
export function pySplit(s: string): string[] {
  return pyStrip(s)
    .split(WS_RUN)
    .filter((w) => w.length > 0);
}

/** Python `re.sub(r'\s+', ' ', s)`. */
export function collapseWs(s: string): string {
  return s.replace(WS_RUN, " ");
}

/** Convert Arabic-Indic / Extended Arabic-Indic digits to ASCII (Python int() accepts them natively). */
export function asciiDigits(s: string): string {
  return s
    .replace(/[٠-٩]/g, (d) => String(d.charCodeAt(0) - 0x0660))
    .replace(/[۰-۹]/g, (d) => String(d.charCodeAt(0) - 0x06f0));
}

/** Python `int(float(s))`; returns null where Python would raise ValueError. */
export function pyIntFloat(s: string): number | null {
  const t = asciiDigits(pyStrip(s)).replace(/_/g, "");
  if (!/^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$/.test(t)) return null;
  const n = Number(t);
  if (!Number.isFinite(n)) return null;
  return Math.trunc(n);
}

/** Python `int(s)` for a string that matched `\d+`. */
export function pyInt(s: string): number {
  return parseInt(asciiDigits(s), 10);
}

/** Python: `str.lstrip(chars)` — strips any leading character contained in `chars`. */
export function pyLstrip(s: string, chars: string): string {
  let i = 0;
  while (i < s.length && chars.includes(s[i]!)) i++;
  return s.slice(i);
}

/** التشكيل + التطويل: [ؐ-ًؚ-ٰٟۖ-ۭـ] */
const TASHKEEL = /[ؐ-ًؚ-ٰٟۖ-ۭـ]/g;

/**
 * تطبيع عربي للمطابقة والبحث: حذف التشكيل والتطويل، توحيد الألف/الياء/التاء المربوطة/الهمزات.
 * Identical to the Python reference:
 *   t = TASHKEEL.sub('', t or '')
 *   t = re.sub('[إأآٱ]', 'ا', t)
 *   t = t.replace('ى','ي').replace('ة','ه').replace('ؤ','و').replace('ئ','ي')
 *   return re.sub(r'\s+', ' ', t).strip()
 */
export function normalize(input: string | null | undefined): string {
  let t = (input ?? "").replace(TASHKEEL, "");
  t = t.replace(/[إأآٱ]/g, "ا"); // إ أ آ ٱ → ا
  t = t
    .replace(/ى/g, "ي") // ى → ي
    .replace(/ة/g, "ه") // ة → ه
    .replace(/ؤ/g, "و") // ؤ → و
    .replace(/ئ/g, "ي"); // ئ → ي
  return pyStrip(collapseWs(t));
}
