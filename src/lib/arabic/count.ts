/** صيغ العدد العربية: مفرد ومثنى وجمع قلّة (٣–١٠) وجمع كثرة (١١+). */
export type CountForms = { one: string; two: string; few: string; many: string };

export const POSITIONS: CountForms = { one: "موضع واحد", two: "موضعان", few: "مواضع", many: "موضعًا" };
export const VERSES: CountForms = { one: "آية واحدة", two: "آيتان", few: "آيات", many: "آية" };
export const SITUATIONS: CountForms = { one: "حالة واحدة", two: "حالتان", few: "حالات", many: "حالة" };
export const HADITHS: CountForms = { one: "حديث واحد", two: "حديثان", few: "أحاديث", many: "حديثًا" };
export const NAMES: CountForms = { one: "اسم واحد", two: "اسمان", few: "أسماء", many: "اسمًا" };
export const WITNESSES: CountForms = { one: "شاهد واحد", two: "شاهدان", few: "شواهد", many: "شاهدًا" };

/** «موضع واحد» · «موضعان» · «٥ مواضع» · «٣٢ موضعًا». */
export function arabicCount(n: number, forms: CountForms): string {
  if (n === 1) return forms.one;
  if (n === 2) return forms.two;
  return `${n.toLocaleString("en-US")} ${n <= 10 ? forms.few : forms.many}`;
}

/** «N آيات · M أحاديث» مع إخفاء الجزء الصفري؛ فارغة إذا كان كلاهما صفرًا. */
export function supportLabel(verses: number, hadiths: number): string {
  const parts: string[] = [];
  if (verses > 0) parts.push(arabicCount(verses, VERSES));
  if (hadiths > 0) parts.push(arabicCount(hadiths, HADITHS));
  return parts.join(" · ");
}
