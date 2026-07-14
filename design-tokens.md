# RIP Design Tokens — Canonical Specification

**Version:** 1.0.0  
**Status:** Mandatory for all portal UI work (Phase 5+)  
**Governance:** `code_style.md` §3.3, this document, `.interface-design/system.md` (runtime)  
**Color space:** OKLCH exclusively (no hex in source tokens)  
**Skills applied:** `better-colors`, `better-typography`, `better-ui`, `interface-design`, `impeccable`, `shadcn`

---

## 1. Purpose

This document is the **single source of truth** for all visual design decisions in the Retail Intelligence Platform admin portal. Every color, spacing value, type size, shadow, radius, and motion duration must trace to a token defined here — never to ad-hoc Tailwind literals (`bg-gray-200`, `text-blue-500`) or raw hex.

RIP is an **enterprise operations command center** (Datadog × Stripe × Linear). The aesthetic is: **dense, precise, calm authority** — not marketing fluff, not generic SaaS cream templates.

### Product intent (from SRS + interface-design skill)

| Dimension | Decision |
|-----------|----------|
| **Who** | LP investigators, store managers, regional directors, ML engineers — often under time pressure, reviewing evidence |
| **Task verb** | Triage theft alerts, monitor store health, configure digital twins, audit checkout discrepancies |
| **Feel** | Cold like a terminal, dense like a trading floor, calm like a reading app — **operational clarity over decoration** |
| **Register** | Product UI (design serves the product), not marketing |
| **Color strategy** | **Restrained**: tinted neutrals + one accent ≤10% surface; semantic colors for status only |
| **Depth strategy** | **Borders-only** with whisper-quiet surface elevation (Linear/Vercel pattern) |
| **Density** | **Workbench-tight** for LP/Operations (12–16px component padding); **airy** for Executive dashboards (20–24px) |

---

## 2. Token Architecture

### 2.1 Layer model

```
primitives/     → Raw OKLCH values (never used directly in components)
semantic/       → Role-based aliases (foreground, background, border, brand)
component/      → Control-specific (input-bg, sidebar-border, alert-critical)
domain/         → RIP-specific (theft-score-high, camera-offline, blind-spot-zone)
```

### 2.2 File locations (monorepo)

| File | Purpose |
|------|---------|
| `packages/ui/tokens/primitives.css` | OKLCH primitive ramps |
| `packages/ui/tokens/semantic.css` | Semantic role mappings |
| `packages/ui/tokens/component.css` | Input, card, sidebar, table tokens |
| `packages/ui/tokens/domain.css` | LP, twin, camera, checkout tokens |
| `packages/ui/tokens/motion.css` | Duration, easing curves |
| `packages/ui/tokens/typography.css` | Type scale, font stacks |
| `packages/ui/tokens/spacing.css` | Spacing scale (4px base) |
| `packages/ui/tokens/radius.css` | Border radius scale |
| `packages/ui/tokens/shadow.css` | Elevation shadows |
| `apps/portal/app/globals.css` | `@import` all token files + Tailwind v4 `@theme` |
| `.interface-design/system.md` | Runtime design decisions (auto-generated from impeccable `document`) |

### 2.3 Tailwind v4 `@theme` binding

All tokens exposed to Tailwind via `@theme` in `globals.css`:

```css
@theme {
  --color-background: var(--rip-bg-canvas);
  --color-foreground: var(--rip-fg-primary);
  /* ... full mapping in packages/ui/tokens/tailwind-bridge.css */
}
```

**Rule:** Components use `bg-background`, `text-muted-foreground`, `border-border` — never `bg-[oklch(...)]` inline except in token definition files.

---

## 3. Color System (OKLCH)

### 3.1 Primitive ramps

Hue anchor: **250°** (cool blue-neutral — operational, not warm cream). Chroma tinted toward brand hue at **C 0.008–0.015** on neutrals.

#### Neutral ramp (structure)

| Token | Light mode OKLCH | Dark mode OKLCH | Role |
|-------|------------------|-----------------|------|
| `--rip-neutral-0` | `oklch(0.99 0.005 250)` | `oklch(0.14 0.012 250)` | Canvas base |
| `--rip-neutral-50` | `oklch(0.97 0.006 250)` | `oklch(0.17 0.012 250)` | Subtle bg |
| `--rip-neutral-100` | `oklch(0.94 0.007 250)` | `oklch(0.20 0.013 250)` | Elevated +1 |
| `--rip-neutral-200` | `oklch(0.90 0.008 250)` | `oklch(0.24 0.014 250)` | Elevated +2 |
| `--rip-neutral-300` | `oklch(0.82 0.009 250)` | `oklch(0.30 0.015 250)` | Borders soft |
| `--rip-neutral-400` | `oklch(0.70 0.010 250)` | `oklch(0.40 0.014 250)` | Borders standard |
| `--rip-neutral-500` | `oklch(0.55 0.010 250)` | `oklch(0.55 0.012 250)` | Muted fg |
| `--rip-neutral-600` | `oklch(0.45 0.009 250)` | `oklch(0.65 0.010 250)` | Secondary fg |
| `--rip-neutral-700` | `oklch(0.35 0.008 250)` | `oklch(0.75 0.008 250)` | Primary fg alt |
| `--rip-neutral-800` | `oklch(0.25 0.007 250)` | `oklch(0.85 0.006 250)` | Headings |
| `--rip-neutral-900` | `oklch(0.18 0.006 250)` | `oklch(0.93 0.005 250)` | Display |
| `--rip-neutral-950` | `oklch(0.12 0.005 250)` | `oklch(0.98 0.004 250)` | Ink |

#### Brand accent (≤10% of surface area)

| Token | OKLCH | Usage |
|-------|-------|-------|
| `--rip-brand-400` | `oklch(0.72 0.14 250)` | Hover accents |
| `--rip-brand-500` | `oklch(0.58 0.16 250)` | Primary actions, focus rings |
| `--rip-brand-600` | `oklch(0.48 0.15 250)` | Active/pressed |
| `--rip-brand-700` | `oklch(0.40 0.13 250)` | Dark mode primary |

#### Semantic colors (desaturated in dark mode)

| Token | Light OKLCH | Meaning |
|-------|-------------|---------|
| `--rip-success-500` | `oklch(0.55 0.14 145)` | Matched checkout, camera online |
| `--rip-warning-500` | `oklch(0.72 0.16 75)` | Degraded mode, minor discrepancy |
| `--rip-destructive-500` | `oklch(0.55 0.20 25)` | Theft alert, major discrepancy, camera offline |
| `--rip-info-500` | `oklch(0.58 0.12 230)` | Informational, neutral alerts |

### 3.2 Semantic mappings

| Semantic token | Light | Dark | Maps to |
|----------------|-------|------|---------|
| `--rip-bg-canvas` | neutral-0 | neutral-0 | Page background |
| `--rip-bg-surface` | neutral-50 | neutral-100 | Cards, panels |
| `--rip-bg-surface-raised` | neutral-100 | neutral-200 | Dropdowns, popovers |
| `--rip-bg-inset` | neutral-100 (darker than parent) | neutral-50 | Inputs (inset = darker) |
| `--rip-fg-primary` | neutral-900 | neutral-800 | Body, headings |
| `--rip-fg-secondary` | neutral-600 | neutral-600 | Supporting text |
| `--rip-fg-tertiary` | neutral-500 | neutral-500 | Metadata |
| `--rip-fg-muted` | neutral-400 | neutral-400 | Disabled, placeholders |
| `--rip-border-default` | `oklch(0.90 0.008 250 / 0.6)` | `oklch(1 0 0 / 0.08)` | Standard borders |
| `--rip-border-subtle` | `oklch(0.94 0.007 250 / 0.5)` | `oklch(1 0 0 / 0.05)` | Section dividers |
| `--rip-border-focus` | brand-500 | brand-400 | Focus rings |
| `--rip-brand` | brand-500 | brand-400 | Primary CTA |
| `--rip-brand-fg` | `oklch(0.99 0 0)` | `oklch(0.12 0.005 250)` | Text on brand |

### 3.3 Domain tokens (RIP-specific)

| Token | OKLCH / value | Usage |
|-------|---------------|-------|
| `--rip-theft-score-low` | success-500 @ 0.6 opacity | Score 0.0–0.3 |
| `--rip-theft-score-medium` | warning-500 | Score 0.3–0.6 |
| `--rip-theft-score-high` | destructive-500 | Score 0.6–0.85 |
| `--rip-theft-score-critical` | `oklch(0.45 0.22 25)` | Score > 0.85 |
| `--rip-camera-online` | success-500 | Live indicator dot |
| `--rip-camera-degraded` | warning-500 | Partial outage |
| `--rip-camera-offline` | destructive-500 | No heartbeat |
| `--rip-blind-spot-zone` | `oklch(0.55 0.18 25 / 0.25)` | Twin coverage overlay |
| `--rip-visible-zone` | `oklch(0.58 0.12 145 / 0.15)` | Camera coverage overlay |
| `--rip-trajectory-path` | brand-500 @ 0.7 | Investigation trajectory line |
| `--rip-heatmap-cold` | `oklch(0.65 0.10 145)` | Footfall heatmap min |
| `--rip-heatmap-hot` | `oklch(0.55 0.20 25)` | Footfall heatmap max |
| `--rip-checkout-matched` | success-500 | DTW MATCH status |
| `--rip-checkout-discrepancy` | destructive-500 | DTW MAJOR_DISCREPANCY |

### 3.4 Contrast requirements (WCAG 2.1 AA + APCA)

| Pair | Minimum | Verified |
|------|---------|----------|
| `--rip-fg-primary` on `--rip-bg-canvas` | 4.5:1 (WCAG), \|Lc\| ≥ 75 (APCA body) | Required in CI |
| `--rip-fg-secondary` on `--rip-bg-surface` | 4.5:1 | Required |
| `--rip-fg-muted` on `--rip-bg-surface` | 4.5:1 (not default gray washout) | Required |
| Large text (≥24px) on any bg | 3:1 | Required |
| Focus ring on any control | 3:1 against adjacent | Required |

**Forbidden:** Muted gray body text on tinted near-white (impeccable anti-pattern). If contrast is close, bump foreground L toward ink end.

### 3.5 White-label / tenant overrides

Tenants override via middleware-injected CSS variables:

```css
:root[data-tenant="acme"] {
  --rip-brand-500: oklch(0.52 0.18 30); /* tenant primary */
  --rip-brand-600: oklch(0.44 0.16 30);
}
```

**Rule:** Tenants may override `--rip-brand-*` and logo URLs only. Neutral ramp and semantic structure are fixed for accessibility.

---

## 4. Typography

### 4.1 Font stacks

| Token | Stack | Role |
|-------|-------|------|
| `--rip-font-sans` | `"Geist Sans", "Inter", system-ui, sans-serif` | UI default |
| `--rip-font-mono` | `"Geist Mono", "JetBrains Mono", ui-monospace, monospace` | Code, event IDs, SQL |
| `--rip-font-display` | `var(--rip-font-sans)` | Headings (same family, weight differentiation) |

**Load:** `.woff2` only via `next/font/local` or `next/font/google`. `font-synthesis: none` on root.

### 4.2 Type scale (ratio 1.25 — minor third)

Base: **14px** (`0.875rem`) for workbench density. Executive views may use 16px base via `data-density="comfortable"`.

| Token | Size | Line-height | Weight | Letter-spacing | Usage |
|-------|------|-------------|--------|----------------|-------|
| `--rip-text-caption` | 11px / 0.6875rem | 1.35 | 500 | 0.02em | Eyebrows (max 1 per view), timestamps |
| `--rip-text-xs` | 12px / 0.75rem | 1.4 | 400 | 0 | Meta, badges |
| `--rip-text-sm` | 13px / 0.8125rem | 1.45 | 400 | 0 | Table cells, compact UI |
| `--rip-text-base` | 14px / 0.875rem | 1.5 | 400 | 0 | Body default |
| `--rip-text-md` | 16px / 1rem | 1.5 | 400 | 0 | Comfortable density body |
| `--rip-text-lg` | 18px / 1.125rem | 1.4 | 500 | -0.01em | Section titles |
| `--rip-text-xl` | 22px / 1.375rem | 1.3 | 600 | -0.02em | Page titles |
| `--rip-text-2xl` | 28px / 1.75rem | 1.2 | 600 | -0.03em | Dashboard heroes |
| `--rip-text-display` | clamp(2rem, 4vw, 3.5rem) | 1.1 | 600 | -0.03em | Metric heroes (max 6rem ceiling) |

### 4.3 Text hierarchy (weight + opacity, not size alone)

| Level | Classes | Spec |
|-------|---------|------|
| Primary | `text-foreground font-medium` | Values, active nav |
| Secondary | `text-muted-foreground font-normal` | Labels, descriptions |
| Tertiary | `text-muted-foreground/80` | Metadata |
| Muted | `text-muted-foreground/60` | Disabled (still 4.5:1 on bg) |

### 4.4 Numeric data

| Rule | Implementation |
|------|----------------|
| Tabular numbers | `font-variant-numeric: tabular-nums` on all dynamic numbers |
| Theft scores | `tabular-nums` + domain color token |
| Timestamps | Mono font, `--rip-text-xs` |
| Event IDs | Mono, truncate + tooltip |

### 4.5 Text wrapping

| Element | Property |
|---------|----------|
| h1–h3 | `text-wrap: balance` |
| Body, descriptions | `text-wrap: pretty` |
| Table cells | `truncate` + tooltip if clipped |
| Long-form (rare) | `max-w-prose` (~65ch) |

---

## 5. Spacing

### 5.1 Base unit: 4px

| Token | Value | Usage |
|-------|-------|-------|
| `--rip-space-0` | 0 | — |
| `--rip-space-1` | 4px | Icon gaps (micro) |
| `--rip-space-2` | 8px | Inline gaps |
| `--rip-space-3` | 12px | Compact component padding |
| `--rip-space-4` | 16px | Default component padding (workbench) |
| `--rip-space-5` | 20px | — |
| `--rip-space-6` | 24px | Section gaps (comfortable) |
| `--rip-space-8` | 32px | Major section breaks |
| `--rip-space-10` | 40px | Page section margins |
| `--rip-space-12` | 48px | — |
| `--rip-space-16` | 64px | Hero spacing |

### 5.2 Density modes

| Mode | `data-density` | Component pad | Section gap | Context |
|------|----------------|---------------|-------------|---------|
| Workbench | `compact` (default) | 12–16px | 16px | LP, Operations, AI |
| Comfortable | `comfortable` | 20–24px | 24–32px | Executive dashboard |

### 5.3 Layout proportions

| Element | Width | Rationale |
|---------|-------|-----------|
| Sidebar | 260px | Navigation serves content |
| LP investigation video pane | 60% | Focal element |
| Twin canvas min | 480px | R3F interaction |
| Camera wall tile | 1fr grid, min 200px | Virtualized grid |

---

## 6. Border Radius (concentric rule)

| Token | Value | Usage |
|-------|-------|-------|
| `--rip-radius-sm` | 4px | Badges, tags |
| `--rip-radius-md` | 6px | Buttons, inputs |
| `--rip-radius-lg` | 8px | Cards (max for cards — impeccable: no 32px cards) |
| `--rip-radius-xl` | 12px | Modals, sheets |
| `--rip-radius-full` | 9999px | Avatars, status dots only |

**Concentric rule:** `outerRadius = innerRadius + padding`. Card `lg` (8px) + padding 16px → inner button `md` (6px) is wrong; use `outer 14px = 6 + 8`.

---

## 7. Depth & Borders

### 7.1 Strategy: borders-only (committed)

No ghost-card pattern (1px border + 16px blur shadow on same element — forbidden).

| Token | Light | Dark |
|-------|-------|------|
| `--rip-border-default` | `oklch(0.90 0.008 250 / 0.55)` | `oklch(1 0 0 / 0.08)` |
| `--rip-border-emphasis` | `oklch(0.82 0.009 250 / 0.7)` | `oklch(1 0 0 / 0.12)` |

### 7.2 Surface elevation (whisper-quiet)

| Level | Light ΔL | Dark ΔL |
|-------|----------|---------|
| Base (canvas) | 0 | 0 |
| Surface +1 | +0.03 L | +0.03 L |
| Surface +2 (dropdown) | +0.06 L | +0.05 L |

**Sidebar:** Same background as canvas + `--rip-border-subtle` right border only.

**Inputs:** `--rip-bg-inset` (darker than parent) — signals "type here".

### 7.3 Z-index scale (semantic, never 9999)

| Token | Value | Layer |
|-------|-------|-------|
| `--rip-z-dropdown` | 50 | Dropdowns, popovers |
| `--rip-z-sticky` | 100 | Sticky table headers |
| `--rip-z-modal-backdrop` | 200 | Overlay scrim |
| `--rip-z-modal` | 210 | Dialog, sheet |
| `--rip-z-toast` | 300 | Sonner toasts |
| `--rip-z-tooltip` | 400 | Tooltips |

---

## 8. Motion

### 8.1 Durations

| Token | Value | Usage |
|-------|-------|-------|
| `--rip-duration-instant` | 100ms | Button press feedback |
| `--rip-duration-fast` | 150ms | Hover states |
| `--rip-duration-normal` | 200ms | Dropdowns, popovers |
| `--rip-duration-slow` | 300ms | Modals, drawers (max for UI) |
| `--rip-duration-evidence` | 100ms | Video drift correction tick |

### 8.2 Easing

| Token | Curve | Usage |
|-------|-------|-------|
| `--rip-ease-out` | `cubic-bezier(0.23, 1, 0.32, 1)` | Enter, interactive (never ease-in) |
| `--rip-ease-in-out` | `cubic-bezier(0.77, 0, 0.175, 1)` | On-screen movement |
| `--rip-ease-spring` | `cubic-bezier(0.2, 0, 0, 1)` | Icon cross-fade (no bounce) |

### 8.3 Motion rules

| Rule | Implementation |
|------|----------------|
| No animation on keyboard shortcuts | Command palette, search: 0ms |
| Press feedback | `active:scale-[0.96]` (never below 0.95) |
| Never scale from 0 | Enter: `scale(0.95)` + `opacity: 0` |
| Popover origin | `transform-origin` at trigger, not center |
| Animate only | `transform`, `opacity` |
| Never | `transition: all` |
| Reduced motion | `@media (prefers-reduced-motion: reduce)` → opacity only |
| Stagger | 30–80ms between list items on enter |

---

## 9. Component Tokens

### 9.1 Button

| Variant | Background | Foreground | Border | Height |
|---------|------------|------------|--------|--------|
| primary | `--rip-brand` | `--rip-brand-fg` | none | 36px |
| secondary | transparent | `--rip-fg-primary` | `--rip-border-default` | 36px |
| ghost | transparent | `--rip-fg-secondary` | none | 36px |
| destructive | `--rip-destructive-500` | white | none | 36px |

Padding: `12px 16px`. Radius: `--rip-radius-md`. Hit area: min 40×40px (44×44 touch contexts).

### 9.2 Input / Select

| Property | Token |
|----------|-------|
| Background | `--rip-bg-inset` |
| Border | `--rip-border-default` |
| Focus ring | 2px `--rip-border-focus` |
| Height | 36px (40px comfortable) |
| Font | `--rip-text-base` |
| Mobile | min 16px font (iOS zoom prevention) |

### 9.3 Card

| Property | Token |
|----------|-------|
| Background | `--rip-bg-surface` |
| Border | `--rip-border-subtle` |
| Radius | `--rip-radius-lg` (8px max) |
| Padding | `--rip-space-4` (compact) / `--rip-space-6` (comfortable) |
| Shadow | none (borders-only strategy) |

### 9.4 Data table (LP queue, audit logs)

| Property | Spec |
|----------|------|
| Row height | 40px compact / 48px comfortable |
| Header | `--rip-text-xs`, uppercase, `letter-spacing: 0.04em`, `--rip-fg-tertiary` |
| Cell numbers | `tabular-nums` |
| Row hover | `--rip-bg-surface` +1 level |
| Virtualization | `@tanstack/react-virtual` mandatory > 100 rows |

### 9.5 Alert / Investigation card

| Severity | Left accent | Background |
|----------|-------------|------------|
| critical | **none** (no side-stripe — impeccable ban) | `--rip-destructive-500` @ 0.08 bg tint |
| warning | none | `--rip-warning-500` @ 0.08 |
| info | none | `--rip-info-500` @ 0.08 |

Use full border or background tint — never `border-left: 4px solid`.

### 9.6 R3F Digital Twin canvas

| Element | Color token |
|---------|-------------|
| Floor grid | `--rip-border-subtle` |
| Walls/fixtures | `--rip-neutral-300` / `--rip-neutral-600` |
| Live tracklet dot | `--rip-brand-500` |
| Theft suspect dot | `--rip-destructive-500` |
| Blind spot overlay | `--rip-blind-spot-zone` |
| Coverage overlay | `--rip-visible-zone` |
| Trajectory line | `--rip-trajectory-path` |

---

## 10. shadcn/ui Integration

### 10.1 Required mapping

Map shadcn CSS variables to RIP tokens in `globals.css`:

```css
:root {
  --background: var(--rip-bg-canvas);
  --foreground: var(--rip-fg-primary);
  --card: var(--rip-bg-surface);
  --card-foreground: var(--rip-fg-primary);
  --popover: var(--rip-bg-surface-raised);
  --popover-foreground: var(--rip-fg-primary);
  --primary: var(--rip-brand);
  --primary-foreground: var(--rip-brand-fg);
  --secondary: var(--rip-neutral-100);
  --secondary-foreground: var(--rip-fg-primary);
  --muted: var(--rip-neutral-100);
  --muted-foreground: var(--rip-fg-secondary);
  --accent: var(--rip-neutral-100);
  --accent-foreground: var(--rip-fg-primary);
  --destructive: var(--rip-destructive-500);
  --border: var(--rip-border-default);
  --input: var(--rip-border-default);
  --ring: var(--rip-border-focus);
  --radius: var(--rip-radius-md);
}
```

### 10.2 shadcn rules (from skill)

- Use `flex gap-*` not `space-x/y-*`
- Use `size-*` for square dimensions
- `FieldGroup` + `Field` for forms
- `DialogTitle` required (sr-only if hidden)
- Semantic colors only — no `bg-blue-500`
- Compose existing components before custom markup

---

## 11. Accessibility Tokens

| Requirement | Token / rule |
|-------------|--------------|
| Focus visible | 2px `--rip-border-focus` outline, offset 2px |
| Skip link | `--rip-skip-link` positioned off-screen until focus |
| Touch target | min 44×44px mobile, 40×40px desktop |
| Screen reader twin summary | Parallel HTML table updated on R3F interaction |
| Chart aria | `aria-label` generated from data payload |
| Reduced motion | All movement tokens → 0 under `prefers-reduced-motion` |

---

## 12. CI & Governance

### 12.1 Token compliance checks

| Check | Tool | Gate |
|-------|------|------|
| No raw hex in components | ESLint custom rule `rip/no-raw-color` | Block PR |
| Contrast ratios | `accesslint/skills@audit` in CI | AA minimum |
| shadcn structure | `shadcn` skill rules in review | Manual + lint |
| Design drift | Compare against `.interface-design/system.md` | Phase 5+ |

### 12.2 Phase 0 bootstrap tickets (design system foundation)

| Ticket | Task |
|--------|------|
| RIP-0-055 | Create `packages/ui/tokens/*.css` from this document |
| RIP-0-056 | Wire Tailwind v4 `@theme` in `apps/portal/app/globals.css` |
| RIP-0-057 | Add ESLint `rip/no-raw-color` rule |
| RIP-0-058 | Document token workflow in `docs/runbooks/design-tokens.md` |

---

## 13. Anti-Patterns (Absolute Bans)

From `impeccable` + `interface-design` — violations block merge:

- Cream/sand/beige body backgrounds (OKLCH L 0.84–0.97, C < 0.06, hue 40–100)
- Gradient text (`background-clip: text`)
- Side-stripe borders (`border-left: 4px` accent on cards)
- Ghost cards (1px border + 16px+ shadow on same element)
- `border-radius: 32px+` on cards
- Identical icon+heading+text card grids
- Tiny uppercase tracked eyebrow on every section
- `transition: all`
- Raw `gray-200` / `#fff` in component code
- Nested cards
- `scale(0)` enter animations
- `ease-in` on dropdowns

---

**End of Design Tokens Specification**
