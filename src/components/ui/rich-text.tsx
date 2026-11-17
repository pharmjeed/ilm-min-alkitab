/**
 * RichText — content text with `**bold**` runs and kept line breaks (src/lib/markdown-lite.ts).
 * Markdown — about / methodology pages: headings, paragraphs, lists, bold.
 */
import { View } from "react-native";

import { parseBlocks, parseInline, type Run } from "@/lib/markdown-lite";
import { SPACE, TYPE, type ColorName, type TextVariant } from "@/theme";

import { AppText, Span, type AppTextProps } from "./app-text";

function runsToNodes(runs: Run[], variant: TextVariant, boldColor?: ColorName) {
  const role = TYPE[variant].role;
  return runs.map((r, i) =>
    r.bold ? (
      <Span key={i} fontRole={role} weight="bold" color={boldColor}>
        {r.text}
      </Span>
    ) : (
      r.text
    ),
  );
}

export interface RichTextProps extends Omit<AppTextProps, "children"> {
  text: string | null | undefined;
  /** Colour of bold runs (defaults to the text colour). */
  boldColor?: ColorName;
}

export function RichText({ text, variant = "body", boldColor, ...rest }: RichTextProps) {
  if (!text) return null;
  return (
    <AppText variant={variant} {...rest}>
      {runsToNodes(parseInline(text), variant, boldColor)}
    </AppText>
  );
}

export interface MarkdownProps {
  source: string | null | undefined;
  /** Shown when the source is empty. */
  emptyText?: string;
}

export function Markdown({ source, emptyText = "لا يوجد نص لهذا القسم." }: MarkdownProps) {
  const blocks = parseBlocks(source);
  if (!blocks.length) return <AppText color="muted">{emptyText}</AppText>;
  return (
    <View style={{ gap: SPACE.md }}>
      {blocks.map((b, i) => {
        if (b.type === "heading") {
          if (b.level === 3) {
            return (
              <AppText key={i} variant="body" weight="bold" color="gold" accessibilityRole="header">
                {runsToNodes(b.runs, "body")}
              </AppText>
            );
          }
          const variant = b.level === 1 ? "h2" : "h3";
          return (
            <AppText key={i} variant={variant} accessibilityRole="header" style={{ marginTop: i ? SPACE.sm : 0 }}>
              {runsToNodes(b.runs, variant)}
            </AppText>
          );
        }
        if (b.type === "paragraph") {
          return (
            <AppText key={i} color="text90">
              {runsToNodes(b.runs, "body")}
            </AppText>
          );
        }
        return (
          <View key={i} style={{ gap: SPACE.sm }}>
            {b.items.map((runs, j) => (
              <View key={j} style={{ flexDirection: "row", gap: SPACE.sm }}>
                <AppText color="gold" style={{ minWidth: 18 }}>
                  {b.ordered ? `${j + 1}.` : "•"}
                </AppText>
                <AppText color="text90" style={{ flex: 1 }}>
                  {runsToNodes(runs, "body")}
                </AppText>
              </View>
            ))}
          </View>
        );
      })}
    </View>
  );
}
