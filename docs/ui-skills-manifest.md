# RIP UI Skills Manifest

**Source list:** `ui-skills.md` (110 skills catalogued)  
**Installed:** 47 skills globally at `~/.agents/skills/`  
**Applied to:** `design-tokens.md`, Phase 5 portal plan, `code_style.md` portal section

---

## Installation Summary

### Successfully installed (47)

| Skill | Repo | RIP relevance |
|-------|------|---------------|
| ui-skills-root | ibelick/ui-skills | Routing layer for all UI work |
| baseline-ui | ibelick/ui-skills | Quick polish pass |
| fixing-accessibility | ibelick/ui-skills | ARIA, keyboard, contrast fixes |
| fixing-metadata | ibelick/ui-skills | SEO, OG tags for portal pages |
| fixing-motion-performance | ibelick/ui-skills | GPU-composited animations only |
| audit | accesslint/skills | Accessibility audit workflow |
| scan | accesslint/skills | Automated a11y scan |
| diff | accesslint/skills | A11y regression diff |
| turborepo | antfu/skills | Monorepo pipelines |
| pnpm | antfu/skills | Package manager |
| vitest | antfu/skills | Portal unit tests |
| web-design-guidelines | antfu/skills + vercel-labs | UI compliance review |
| vercel-react-best-practices | vercel-labs/agent-skills | RSC, performance |
| vercel-composition-patterns | vercel-labs/agent-skills | Component architecture |
| vercel-react-view-transitions | vercel-labs/agent-skills | Page transitions |
| vercel-optimize | vercel-labs/agent-skills | Cost/perf optimization |
| agent-browser | vercel-labs/agent-browser | Browser automation QA |
| better-colors | jakubkrehel/skills | OKLCH tokens (design-tokens.md) |
| better-typography | jakubkrehel/skills | Type scale, fonts |
| better-ui | jakubkrehel/skills | Polish, motion, surfaces |
| emil-design-eng | emilkowalski/skills | Animation decisions |
| interface-design | dammyjay93/interface-design | Dashboard/admin craft |
| design-an-interface | mattpocock/skills | API/module design |
| frontend-design | anthropics/skills | Distinctive UI |
| frontend-ui-engineering | addyosmani/agent-skills | Component architecture |
| api-and-interface-design | addyosmani/agent-skills | API design |
| impeccable | pbakaus/impeccable | Full UI lifecycle (audit/polish/shape) |
| shadcn | shadcn-ui/ui | Component system |
| budge | millionco/budge | Live Tailwind tuning |
| react-doctor | millionco/react-doctor | React quality scan |
| playwright-cli | microsoft/playwright-cli | E2E automation |
| playwright-best-practices | currents-dev/... | E2E patterns |
| ui-ux-pro-max | nextlevelbuilder/... | Design intelligence |
| wcag-audit-patterns | wshobson/agents | WCAG 2.2 audits |
| interaction-design | wshobson/agents | Micro-interactions |
| transitions-dev | jakubantalik/transitions.dev | CSS transition patterns |
| threejs-animation | cloudai-x/threejs-skills | R3F animations |
| threejs-fundamentals | cloudai-x/threejs-skills | Scene setup |
| threejs-geometry | cloudai-x/threejs-skills | CSG boxes for twin |
| threejs-interaction | cloudai-x/threejs-skills | Raycasting, selection |
| threejs-lighting | cloudai-x/threejs-skills | Twin lighting |
| threejs-loaders | cloudai-x/threejs-skills | Asset loading |
| threejs-materials | cloudai-x/threejs-skills | PBR materials |
| threejs-postprocessing | cloudai-x/threejs-skills | Effects |
| threejs-shaders | cloudai-x/threejs-skills | Custom shaders |
| threejs-textures | cloudai-x/threejs-skills | Heatmap textures |
| find-skills | (pre-existing) | Skill discovery |

### Failed to install (auth / wrong repo path)

| Listed skill | Reason | Alternate installed |
|--------------|--------|---------------------|
| accesslint/audit-and-fix | Repo has audit/scan/diff only | audit, scan, diff |
| accesslint/contrast-checker | Not in repo | better-colors |
| accesslint/link-purpose | Not in repo | wcag-audit-patterns |
| accesslint/refactor | Not in repo | fixing-accessibility |
| accesslint/use-of-color | Not in repo | better-colors |
| addyosmani/web-quality-audit | Auth failed | vercel-optimize |
| pbakaus/critique, audit, animate... | Single `impeccable` skill covers all | impeccable |
| zeke/swiss-design | Auth failed | — |
| rams/rams | Auth failed | interface-design |
| 0xdesign/design-lab | Auth failed | design-an-interface |
| leonxlnx/* (taste, redesign, output) | Auth failed | interface-design + impeccable |
| raphaelsalaja/* (motion skills) | Auth failed | emil-design-eng + transitions-dev |
| jakubkrehel/oklch-skill | Renamed | better-colors |
| jakubkrehel/make-interfaces-feel-better | Renamed | better-ui |
| nextlevelbuilder (first attempt) | Auth failed | ui-ux-pro-max (second path worked) |
| shadcn-ui/skills | Wrong repo | shadcn-ui/ui@shadcn |
| antfu/vue*, nuxt, pinia | Not RIP stack | Skipped intentionally |
| callstack/react-native | Not RIP stack | Skipped |
| remotion, svelte, swiftui | Not RIP stack | Skipped |

---

## Skills Read In Full (governance synthesis)

The following installed skills were read completely and synthesized into `design-tokens.md` and phase plans:

1. **ui-skills-root** — Route by topic; prefer 1–3 skills max per task
2. **better-colors** — OKLCH only; APCA/WCAG contrast; Tailwind v4 @theme; no hue drift
3. **better-typography** — 1.25 ratio; tabular-nums; 16px inputs on mobile; woff2 only
4. **better-ui** — Concentric radius; scale(0.96) press; no transition:all; 44px hit areas
5. **interface-design** — Product register; borders-only depth; one focal point; restrained color
6. **impeccable** — Anti-slop bans; OKLCH; no cream backgrounds; shape/audit/polish commands
7. **design-an-interface** — Design-twice workflow for APIs/modules
8. **wcag-audit-patterns** — WCAG 2.2 AA target for portal
9. **shadcn** — Semantic tokens; FieldGroup; no space-x/y; compose primitives
10. **emil-design-eng** — Animation frequency framework; ease-out only; no scale(0)
11. **threejs-fundamentals** — R3F scene/camera/renderer patterns for Digital Twin

Remaining 36 installed skills: available on-demand per `ui-skills-root` routing when implementing their specific domains (Playwright E2E, Triton unrelated threejs for Phase 5 R3F only, etc.).

---

## Phase → Skill Mapping

| Phase | Primary skills | When to invoke |
|-------|----------------|----------------|
| 0 | turborepo, pnpm, vitest | Monorepo + token package scaffold |
| 1 | — | Backend only |
| 2 | — | Edge CV only |
| 3 | threejs-geometry, threejs-interaction | Twin backend raycasting validation |
| 4 | — | Cloud reasoning only |
| 5 | interface-design, shadcn, better-*, impeccable, wcag-*, threejs-*, vercel-react-*, playwright-* | **All portal UI work** |
| 6 | playwright-cli, wcag-audit-patterns, impeccable audit | Chaos + compliance certification |

---

## Mandatory UI Workflow (Phase 5+)

Before any portal PR:

1. Read `design-tokens.md` + `.interface-design/system.md` (if exists)
2. Route via `ui-skills-root` — load max 3 skills for the task
3. Use shadcn primitives; bind to semantic tokens only
4. Run `accesslint` scan + contrast check on changed routes
5. Playwright E2E for LP investigation flow
6. `impeccable audit` before merge

---

## Re-install commands (for failed skills)

```bash
npx skills add pbakaus/impeccable@impeccable -g -y --agent cursor
npx skills add wshobson/agents@wcag-audit-patterns -g -y --agent cursor
npx skills add cloudai-x/threejs-skills@threejs-fundamentals -g -y --agent cursor
# Full list: npx skills find <keyword>
```
