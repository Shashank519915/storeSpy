# Design Token Workflow — RIP

**Authority:** `design-tokens.md`, `ui-skills.md`

## Source of Truth

| Layer | Location |
|-------|----------|
| Specification | `design-tokens.md` (repo root) |
| Implementation | `packages/ui/tokens/*.css` |
| Tailwind bridge | `packages/ui/tokens/tailwind-bridge.css` |
| Portal wiring | `apps/portal/app/globals.css` |
| Runtime decisions | `.interface-design/system.md` (Phase 5+) |

## Token Layers

```
primitives.css  → Raw OKLCH (never use in components)
semantic.css    → bg-canvas, fg-primary, border-default
component.css   → button, input, card, table
domain.css      → theft-score, camera-status, twin overlays
```

## Adding a New Token

1. Add primitive to `primitives.css` if new color needed
2. Map to semantic role in `semantic.css` or domain in `domain.css`
3. Expose via `tailwind-bridge.css` `@theme` if Tailwind utility needed
4. Update `design-tokens.md` specification
5. Verify WCAG 2.1 AA contrast (light + dark)
6. Run `pnpm turbo run lint --filter=@rip/portal` (enforces `rip/no-raw-color`)

## Component Usage Rules

| Do | Don't |
|----|-------|
| `bg-background`, `text-muted-foreground` | `bg-gray-200`, `text-blue-500` |
| `var(--rip-brand)` in token files only | `#3b82f6` in components |
| `style={{ backgroundColor: 'var(--rip-camera-online)' }}` | `style={{ backgroundColor: '#22c55e' }}` |
| OKLCH in `tokens/*.css` only | OKLCH inline in JSX |

## White-Label / Tenant Overrides

Middleware injects tenant CSS variables:

```css
:root[data-tenant="acme"] {
  --rip-brand-500: oklch(0.52 0.18 30);
  --rip-brand-600: oklch(0.44 0.16 30);
}
```

Tenants may override `--rip-brand-*` only. Neutral ramp is fixed for accessibility.

## CI Gates

| Check | Tool |
|-------|------|
| No raw hex/rgb/hsl | ESLint `rip/no-raw-color` |
| Token files present | `ci-foundation.yml` design-tokens job |
| Contrast AA | `wcag-audit-patterns` skill (Phase 5+) |

## Skills Reference

| Task | Skill |
|------|-------|
| Color decisions | `better-colors` |
| Typography | `better-typography` |
| Component patterns | `better-ui`, `shadcn` |
| Aesthetic direction | `interface-design` |
| Anti-patterns | `impeccable` |
| Accessibility | `wcag-audit-patterns`, `fixing-accessibility` |

## Phase 0 Tickets

- RIP-0-055: `packages/ui/tokens/*.css` ✅
- RIP-0-056: Tailwind v4 `@theme` in `globals.css` ✅
- RIP-0-057: ESLint `rip/no-raw-color` ✅
- RIP-0-058: This runbook ✅
