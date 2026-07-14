/**
 * ESLint rule: rip/no-raw-color
 * Blocks raw hex, rgb(), hsl(), and ad-hoc Tailwind gray/blue color literals.
 * Source: design-tokens.md §12.1
 */

const RAW_HEX = /#(?:[0-9a-fA-F]{3,4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})\b/;
const RAW_RGB = /\brgb\s*\(/;
const RAW_HSL = /\bhsl\s*\(/;
const FORBIDDEN_TAILWIND_COLORS =
  /\b(?:bg|text|border|ring|fill|stroke|from|to|via|outline|decoration|divide|placeholder|caret|accent|shadow)-(?:gray|slate|zinc|neutral|stone|red|orange|amber|yellow|lime|green|emerald|teal|cyan|sky|blue|indigo|violet|purple|fuchsia|pink|rose)-\d{2,3}\b/;

const ALLOWED_PATHS = [
  /packages\/ui\/tokens\//,
  /design-tokens\.md$/,
  /\.interface-design\//,
];

/** @type {import('eslint').Rule.RuleModule} */
export const noRawColorRule = {
  meta: {
    type: "problem",
    docs: {
      description:
        "Disallow raw color literals — use RIP design tokens via CSS variables or semantic Tailwind classes",
    },
    schema: [],
    messages: {
      rawHex: "Raw hex color '{{value}}' is forbidden. Use RIP design tokens (var(--rip-*)) or semantic Tailwind classes (bg-background, text-muted-foreground).",
      rawRgb: "Raw rgb() color is forbidden. Use RIP design tokens.",
      rawHsl: "Raw hsl() color is forbidden. Use RIP design tokens.",
      tailwindLiteral:
        "Ad-hoc Tailwind color '{{value}}' is forbidden. Use semantic tokens: bg-background, text-foreground, border-border, etc.",
    },
  },
  create(context) {
    const filename = context.filename.replace(/\\/g, "/");
    if (ALLOWED_PATHS.some((p) => p.test(filename))) {
      return {};
    }

    function checkString(node, value) {
      if (typeof value !== "string") return;

      const hexMatch = value.match(RAW_HEX);
      if (hexMatch) {
        context.report({
          node,
          messageId: "rawHex",
          data: { value: hexMatch[0] },
        });
      }
      if (RAW_RGB.test(value)) {
        context.report({ node, messageId: "rawRgb" });
      }
      if (RAW_HSL.test(value)) {
        context.report({ node, messageId: "rawHsl" });
      }

      const twMatch = value.match(FORBIDDEN_TAILWIND_COLORS);
      if (twMatch) {
        context.report({
          node,
          messageId: "tailwindLiteral",
          data: { value: twMatch[0] },
        });
      }
    }

    return {
      Literal(node) {
        if (typeof node.value === "string") {
          checkString(node, node.value);
        }
      },
      TemplateElement(node) {
        checkString(node, node.value.raw);
      },
    };
  },
};

/** @type {import('eslint').ESLint.Plugin} */
export const ripPlugin = {
  rules: {
    "no-raw-color": noRawColorRule,
  },
};
