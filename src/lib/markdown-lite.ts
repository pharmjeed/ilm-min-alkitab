/**
 * Tiny markdown subset for content texts. Pure TS.
 *  - parseInline(): `**bold**` runs; line breaks are kept inside the run text (RichText).
 *  - parseBlocks(): headings (#, ##, ###…), paragraphs (single newlines kept as line breaks, like the
 *    website's `marked` with `breaks: true`), bullet lists (-, *, •) and numbered lists (1. 1) ١.),
 *    each with inline bold (Markdown component for about / methodology pages).
 * Anything else is shown as plain text. No HTML, no links.
 */

export interface Run {
  text: string;
  bold: boolean;
}

export type Block =
  | { type: "heading"; level: 1 | 2 | 3; runs: Run[] }
  | { type: "paragraph"; runs: Run[] }
  | { type: "list"; ordered: boolean; items: Run[][] };

/** Split `**bold**` runs. An unmatched `**` is kept as literal text. Empty runs are dropped. */
export function parseInline(input: string | null | undefined): Run[] {
  const s = input ?? "";
  const runs: Run[] = [];
  const push = (text: string, bold: boolean) => {
    if (!text) return;
    const last = runs[runs.length - 1];
    if (last && last.bold === bold) last.text += text;
    else runs.push({ text, bold });
  };
  let i = 0;
  while (i < s.length) {
    const open = s.indexOf("**", i);
    if (open < 0) break;
    const close = s.indexOf("**", open + 2);
    if (close < 0) break;
    push(s.slice(i, open), false);
    push(s.slice(open + 2, close), true);
    i = close + 2;
  }
  push(s.slice(i), false);
  return runs;
}

/** Plain text of a markdown-lite string (bold markers removed) — for sharing / copying. */
export function stripInline(input: string | null | undefined): string {
  return parseInline(input)
    .map((r) => r.text)
    .join("");
}

const HEADING = /^(#{1,6})[ \t]+(.+?)[ \t]*#*[ \t]*$/;
const BULLET = /^[ \t]*[-*•][ \t]+(.*)$/;
const NUMBERED = /^[ \t]*[0-9٠-٩]+[.)٫-][ \t]+(.*)$/;

export function parseBlocks(md: string | null | undefined): Block[] {
  const lines = (md ?? "").replace(/\r\n?/g, "\n").split("\n");
  const blocks: Block[] = [];
  let para: string[] = [];
  let list: { ordered: boolean; items: string[] } | null = null;

  const flushPara = () => {
    if (para.length) blocks.push({ type: "paragraph", runs: parseInline(para.join("\n")) });
    para = [];
  };
  const flushList = () => {
    if (list) blocks.push({ type: "list", ordered: list.ordered, items: list.items.map(parseInline) });
    list = null;
  };

  for (const raw of lines) {
    const line = raw.trimEnd();
    if (!line.trim()) {
      flushPara();
      flushList();
      continue;
    }
    const h = HEADING.exec(line);
    if (h) {
      flushPara();
      flushList();
      const level = Math.min(3, h[1]!.length) as 1 | 2 | 3;
      blocks.push({ type: "heading", level, runs: parseInline(h[2]!) });
      continue;
    }
    const b = BULLET.exec(line);
    const n = b ? null : NUMBERED.exec(line);
    if (b || n) {
      flushPara();
      const ordered = !!n;
      if (list && list.ordered !== ordered) flushList();
      if (!list) list = { ordered, items: [] };
      list.items.push((b ?? n)![1]!);
      continue;
    }
    if (list) {
      // A plain line right after a list item continues that item.
      list.items[list.items.length - 1] += "\n" + line.trim();
      continue;
    }
    para.push(line.trim());
  }
  flushPara();
  flushList();
  return blocks;
}
