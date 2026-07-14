# RIP Phase 5: Next.js Enterprise Portal & APIs
**Prerequisites:** Phase 4 exit criteria met
**Governance:** code_style.md, design-tokens.md
**Master plan:** rip-execution-plan.md (this is the standalone working copy)


## Phase Objective
Deliver the enterprise admin command center: multi-tenant Next.js App Router portal with RSC data shells, R3F Digital Twin Store Designer, synced multi-angle investigation video player, live MJPEG/WebRTC camera wall, role-based dashboards, GraphQL/REST API gateway with OPA ABAC, real-time WebSocket alert streaming, and NL analytics RAG proxy. At exit, an LP investigator can triage an alert, review synchronized evidence, disposition the case, and trigger the feedback loop — all under ABAC store isolation.

## Sub-systems Involved
- `apps/portal` (Next.js 15 App Router)
- `apps/api-gateway` (Go GraphQL + REST)
- `packages/ui` (Radix + Tailwind)
- `packages/opa-policies` (Rego ABAC)
- OPA sidecar on API gateway
- `apps/llm-gateway` (Python RAG + NeMo Guardrails)
- Kafka → WebSocket bridge
- ClickHouse analytics queries (parameterized, RLS-injected)
- Auth0/Okta OIDC integration
- Edge HLS/MJPEG/WebRTC transcoder (consumer of Phase 2 edge services)

---

## Granular Tasks

### 5.1 API Gateway & OPA ABAC
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-5-001 | `apps/api-gateway` (Go): gqlgen GraphQL + chi REST router | `apps/api-gateway/` |
| RIP-5-002 | OPA sidecar deployment; Rego policies in `packages/opa-policies/` | `packages/opa-policies/` |
| RIP-5-003 | Policy `authz/store_access`: deny if `input.store_id ∉ jwt.store_ids` | `opa-policies/store_access.rego` |
| RIP-5-004 | Policy `authz/lp_evidence`: `LP_Agent` view; `LP_Manager` required for `unblur_face` | `opa-policies/lp_evidence.rego` |
| RIP-5-005 | Policy `authz/analytics`: row-level `store_id` injection into ClickHouse query params | `opa-policies/analytics.rego` |
| RIP-5-006 | JWT validation via JWKS; 15-min access token; refresh via HttpOnly Secure cookie | `api-gateway/internal/auth/` |
| RIP-5-007 | mTLS upstream to PostgreSQL (PgBouncer), ClickHouse, Redis via service mesh | `api-gateway/deploy/` |
| RIP-5-008 | W3C `traceparent` propagation on all GraphQL resolvers | `api-gateway/internal/otel/` |
| RIP-5-009 | RFC 7807 problem+json error responses with `trace_id` | `api-gateway/internal/errors/` |

### 5.2 Next.js Foundation & Multi-Tenancy
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-5-010 | App Router structure: `app/[tenantSlug]/[storeId]/layout.tsx` | `apps/portal/app/` |
| RIP-5-011 | Edge Middleware: JWT JWKS validation; inject `x-tenant-id`, `x-store-id`, `x-user-roles` headers | `apps/portal/middleware.ts` |
| RIP-5-012 | White-label theme registry: tenant config from Redis/Edge Config → CSS variables | `apps/portal/lib/theme/` |
| RIP-5-013 | TanStack Query provider with server-side prefetch via RSC | `apps/portal/lib/query/` |
| RIP-5-014 | Zustand stores: `useUIStore`, `useLiveTracklets`, `useAlertQueue` | `apps/portal/src/stores/` |
| RIP-5-015 | `pnpm` workspace linking to `packages/ui` and `packages/spatial-math` | `apps/portal/package.json` |
| RIP-5-016 | WCAG 2.1 AA: parallel semantic HTML table for R3F scene (screen reader) | `apps/portal/components/twin/a11y-summary.tsx` |

### 5.3 Dashboard Ecosystem (Persona Views)
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-5-020 | Executive Dashboard (RSC): ClickHouse aggregates — footfall, conversion funnel, shrinkage YoY | `apps/portal/app/[tenant]/[store]/executive/page.tsx` |
| RIP-5-021 | Operations Dashboard: camera uptime, queue length, store health score; WebSocket live | `apps/portal/app/.../operations/page.tsx` |
| RIP-5-022 | LP Investigation Center: `InvestigationTask` queue sorted by `SuspicionScore` | `apps/portal/app/.../lp/page.tsx` |
| RIP-5-023 | AI Dashboard: inference latency p50/p99, dropped frames, confidence histograms | `apps/portal/app/.../ai/page.tsx` |
| RIP-5-024 | Inventory Dashboard: PIM vs CV shelf occupancy; OOS highlights | `apps/portal/app/.../inventory/page.tsx` |
| RIP-5-025 | ISR: store list + RBAC roles revalidate every 60s | `apps/portal/app/.../layout.tsx` config |
| RIP-5-026 | `@tanstack/react-virtual` for audit logs and SKU lists > 1000 rows | `apps/portal/components/virtualized/` |

### 5.4 Digital Twin Store Designer (R3F)
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-5-030 | R3F Client Component boundary: `TwinCanvas.tsx` with orthographic top-down default | `apps/portal/components/twin/TwinCanvas.tsx` |
| RIP-5-031 | Scene Graph renderer: CSG boxes for fixtures; polygon lines for aisles | `components/twin/renderers/` |
| RIP-5-032 | Transform gizmos: translate/rotate/scale with 0.5m grid snapping | `components/twin/gizmos/` |
| RIP-5-033 | Component library sidebar: draggable Wall, Gondola, Cooler, Checkout Counter | `components/twin/library/` |
| RIP-5-034 | Camera placement UI: height/pitch/yaw/FoV inputs; frustum cone visualization | `components/twin/camera/` |
| RIP-5-035 | Real-time raycast blind-spot overlay: red semi-transparent zones from twin-api coverage API | `components/twin/coverage/` |
| RIP-5-036 | Homography calibration split-pane: camera snapshot left, floor plan right, 4+ point picker | `components/twin/calibration/` |
| RIP-5-037 | Layer management: HVAC, Electrical, Navigation Graph toggle layers | `components/twin/layers/` |
| RIP-5-038 | Save → `twin-api` mutation → optimistic TanStack Query invalidation | `components/twin/save-handler.ts` |
| RIP-5-039 | Live tracking overlay: WebSocket `tracklet-updated` → colored spheres at (X,Z); Web Worker coordinate math | `components/twin/live-tracklets.tsx` |
| RIP-5-040 | Heatmap overlay: fetch ClickHouse `heatmap_grid`; textured semi-transparent plane | `components/twin/heatmap.tsx` |

### 5.5 Investigation & Synced Video Player
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-5-050 | Custom `SyncedVideoPlayer.tsx`: master clock camera + N secondary streams | `apps/portal/components/investigation/SyncedVideoPlayer.tsx` |
| RIP-5-051 | Master `currentTime` read every 100ms via `requestAnimationFrame` | `SyncedVideoPlayer/useMasterClock.ts` |
| RIP-5-052 | Secondary drift correction: if `|delta| > 50ms`, adjust `playbackRate` to 0.9x/1.1x temporarily | `SyncedVideoPlayer/useDriftCorrection.ts` |
| RIP-5-053 | NTP ingest timestamp metadata from S3 object headers for per-camera timeline offset | `SyncedVideoPlayer/metadata.ts` |
| RIP-5-054 | SVG timeline scrubber: markers for `PickedUp`, `Occluded`, `ConcealmentDetected` | `components/investigation/EventTimeline.tsx` |
| RIP-5-055 | Scrub → seek all players + update cart state side panel at millisecond | `components/investigation/ScrubController.tsx` |
| RIP-5-056 | Trajectory pane: 2D twin path heat-mapped from evidence package API | `components/investigation/TrajectoryPane.tsx` |
| RIP-5-057 | Disposition buttons: `ConfirmedTheft`, `FalsePositive`, `Inconclusive` → GraphQL mutation → Kafka feedback | `components/investigation/DispositionForm.tsx` |
| RIP-5-058 | Face unblur: `LP_Manager` only; OPA gate; audit log entry on authorize | `components/investigation/UnblurGate.tsx` |

### 5.6 Live Camera Wall
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-5-060 | Virtualized CSS grid camera wall; viewport-aware stream loading | `apps/portal/components/camera-wall/CameraGrid.tsx` |
| RIP-5-061 | MJPEG stream for grid tiles (200ms latency acceptable) | `components/camera-wall/MjpegTile.tsx` |
| RIP-5-062 | Double-click tile → tear down MJPEG → establish WebRTC peer via edge signaling server | `components/camera-wall/WebRtcFullscreen.tsx` |
| RIP-5-063 | Adaptive bitrate: edge transcoder reduces HLS fragment resolution on bandwidth drop | `services/edge/hls-transcoder/` (enhance) |
| RIP-5-064 | Twin View toggle: PiP floor plan with live dots from Redis state tooltips | `components/camera-wall/TwinOverlay.tsx` |

### 5.7 Real-Time & Analytics
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-5-070 | Kafka → WebSocket bridge service; subscribes `lp.engine.investigation-task-created` | `apps/realtime-bridge/` |
| RIP-5-071 | GraphQL Subscriptions for LP alerts and live tracklets | `api-gateway/graph/subscription.go` |
| RIP-5-072 | SSE endpoint for system health metrics (lower priority streams) | `api-gateway/internal/sse/` |
| RIP-5-073 | Browser `Notification API` integration on high-severity alert opt-in | `apps/portal/lib/notifications.ts` |
| RIP-5-074 | Analytics Explorer: visual query builder → parameterized ClickHouse SQL | `apps/portal/app/.../analytics/page.tsx` |
| RIP-5-075 | `apps/llm-gateway`: LangChain SQL agent + data dictionary; NeMo Guardrails ABAC | `apps/llm-gateway/` |
| RIP-5-076 | NL chat streams answer + ECharts/Recharts JSON config to frontend | `apps/portal/components/analytics/NlChat.tsx` |
| RIP-5-077 | ClickHouse queries: read-only DB user; `max_execution_time=30s`; `store_id` mandatory filter | `llm-gateway/internal/sql/sandbox.py` |

### 5.8 DLQ Admin & Event Injector UI
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-5-080 | Admin UI: inspect DLQ messages, patch payload, re-inject to primary topic | `apps/portal/app/.../admin/dlq/page.tsx` |
| RIP-5-081 | QA Event Injector UI (dev/staging only): `POST /api/dev/inject-event` guarded by OPA | `apps/portal/app/.../admin/injector/page.tsx` |

---


### 5.9 Design Token & Quality Gates
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-5-090 | Implement portal UI against RIP design tokens: semantic Tailwind classes only (`bg-background`, `text-muted-foreground`, domain tokens) | `apps/portal/`, `packages/ui/` |
| RIP-5-091 | Initialize shadcn/ui; map CSS variables to RIP tokens per `design-tokens.md` §10.1 | `apps/portal/components/ui/`, `apps/portal/app/globals.css` |
| RIP-5-092 | Enforce ESLint `rip/no-raw-color` in portal CI; zero violations on merge | `packages/eslint-config/`, `.github/workflows/` |
| RIP-5-093 | Playwright visual regression baselines: Executive, LP Investigation, Operations dashboards | `apps/portal/e2e/visual/` |
| RIP-5-094 | Integrate `accesslint/skills@audit` in CI for WCAG 2.1 AA on critical portal paths | `.github/workflows/accessibility.yml` |
| RIP-5-095 | Generate `.interface-design/system.md` via impeccable `document`; wire design drift review gate | `.interface-design/system.md` |

---


## UI Skills & Design Governance

Mandatory skills for Phase 5 portal UI work:

| Skill | Application |
|-------|-------------|
| `interface-design` | Product intent, density modes, depth strategy (borders-only) |
| `shadcn` | Component primitives, Field/Dialog patterns, token-mapped CSS variables |
| `better-colors` | OKLCH ramps, contrast verification, restrained accent usage |
| `better-typography` | Type scale, tabular-nums, font loading, hierarchy |
| `better-ui` | Spacing, hover states, press feedback, polish |
| `impeccable` | Anti-pattern bans (ghost cards, side-stripes, cream backgrounds) |
| `wcag-audit-patterns` | WCAG 2.2 audit and remediation for portal surfaces |
| `threejs-fundamentals` | R3F scene setup, cameras, renderer |
| `threejs-materials` | Twin canvas materials mapped to domain tokens |
| `threejs-lighting` | Operational twin lighting (no decorative bloom) |
| `threejs-interaction` | Raycasting, gizmos, camera placement UX |
| `threejs-geometry` | Fixture meshes, coverage overlays |
| `threejs-loaders` | Asset loading for twin components |
| `threejs-postprocessing` | Minimal post-processing (performance-first) |
| `threejs-animation` | Live tracklet motion, gizmo transitions |
| `threejs-textures` | Heatmap planes, coverage overlays |
| `threejs-shaders` | Custom overlays only when token colors insufficient |
| `vercel-react-best-practices` | RSC boundaries, bundle size, data fetching |
| `playwright-cli` | E2E and visual regression automation |

### Mandatory checks (from `design-tokens.md` §12.1)

| Check | Tool | Gate |
|-------|------|------|
| No raw hex in components | ESLint `rip/no-raw-color` | Block PR |
| Contrast ratios | `accesslint/skills@audit` in CI | AA minimum |
| shadcn structure | `shadcn` skill rules in review | Manual + lint |
| Design drift | Compare against `.interface-design/system.md` | Phase 5+ |

---

## Infrastructure/DevOps Tasks (Phase 5)

| Asset | Detail |
|-------|--------|
| Portal deployment | Vercel or EKS + Istio canary; SSR close to ClickHouse region |
| API gateway | 6 replicas, OPA sidecar, HPA on p99 latency |
| `realtime-bridge` | WebSocket sticky sessions via Istio destination rule |
| Edge signaling | WebRTC TURN/STUN for fullscreen camera; coturn Helm on edge |
| CDN | MinIO presigned URLs for evidence video; short TTL 15 min |
| Auth0/Okta | SAML/OIDC app; MFA enforced; role claims → `store_ids` |
| Rate limiting | Redis sliding window per tenant on GraphQL |

---

## Production-Ready Implementation Details (Phase 5)

### Synced Multi-Angle Video Player
1. Load evidence package: cameras `[C1, C2, C3]` with S3 URIs + NTP offset metadata `Δ₁, Δ₂, Δ₃` relative to master `C1`.
2. Designate `C1` as master; `videoRef_master.currentTime` is source of truth.
3. Each 100ms `requestAnimationFrame` tick:
   - `t_master = videoRef_master.currentTime`.
   - For secondary `Cᵢ`: `t_expected = t_master + Δᵢ`.
   - `drift = videoRef_i.currentTime - t_expected`.
   - If `|drift| > 0.05s`: set `playbackRate = drift > 0 ? 0.92 : 1.08`.
   - If `|drift| < 0.02s`: reset `playbackRate = 1.0`.
4. Timeline scrub to `T`: `videoRef_k.currentTime = T + Δₖ` for all k.
5. Side panel queries session snapshot at scrub timestamp from API.

### OPA ABAC Request Flow
1. Request `GET /api/stores/123/lp/investigations` with JWT.
2. API gateway extracts claims: `{sub, roles, store_ids, region_ids}`.
3. OPA query: `data.authz.allow` with `input = {method, path, claims, store_id: 123}`.
4. Rego evaluates: `allow { 123 in input.claims.store_ids; "LP_Agent" in input.claims.roles }`.
5. If deny → 403 problem+json; log `authz_denied` audit event.
6. If allow → resolver executes; ClickHouse query auto-appends `WHERE store_id IN (...)`.

### R3F Store Designer Save Flow
1. User drags Gondola → local Zustand `draftGraph` mutates.
2. Save click → diff against last server version → mutation batch `[ShelfMoved, ...]`.
3. `twin-api` validates `expected_version`; writes Outbox.
4. TanStack Query optimistic update; rollback on 409.
5. Projector updates snapshot; Fleet syncs edge within 5 min.
6. Coverage recalculation job triggered async.

---

## Testing & Validation (Phase 5)

| Test | Procedure | Pass Criteria |
|------|-----------|---------------|
| ABAC isolation | StoreManager token for Store A queries Store B | 403; OPA deny logged |
| LP unblur gate | LP_Agent attempts unblur | 403; LP_Manager succeeds + audit log |
| RSC TTFB | Executive dashboard cold load | TTFB < 800ms; LCP < 2.5s |
| Synced video | 3-camera evidence with 200ms injected drift | Auto-correct to < 50ms within 3s |
| Timeline scrub | Scrub to concealment event | All videos + cart panel match event timestamp |
| R3F performance | 50 live tracklet spheres | 60 FPS on mid-tier laptop |
| Virtualization | Render 10k audit log rows | DOM node count < 100; scroll smooth |
| WebSocket alerts | Emit `InvestigationTask` | Appears in LP queue < 1s |
| NL analytics | "Shrinkage by aisle last week" | Valid ClickHouse SQL; chart rendered; ABAC store filter applied |
| NL injection guard | "Show HR salaries" | NeMo Guardrails blocks; no query executed |
| Playwright E2E | Login → triage → disposition FalsePositive | Feedback event in Kafka; HMM calibrator triggered |
| Camera wall | 16-tile MJPEG grid | Only viewport tiles streaming; bandwidth < 50Mbps |

---

## Exit Criteria (Phase 5)

- [ ] Portal deployed with multi-tenant routing and white-label theming
- [ ] OPA ABAC enforcing store isolation on all API routes
- [ ] Executive, Operations, LP, AI, Inventory dashboards operational
- [ ] R3F Store Designer: draw, place cameras, calibrate homography, view blind spots
- [ ] Synced video player with < 50ms drift across 3+ cameras
- [ ] LP investigation workflow end-to-end including disposition feedback
- [ ] Live camera wall MJPEG grid + WebRTC fullscreen
- [ ] NL analytics with NeMo Guardrails and read-only ClickHouse sandbox
- [ ] DLQ admin UI for poison message re-injection
- [ ] Playwright E2E suite green; WCAG audit passes critical paths
- [ ] Portal components use RIP design tokens exclusively (no raw hex or `gray-*` literals)
- [ ] shadcn/ui initialized with RIP token mapping; all primitives pass `rip/no-raw-color`
- [ ] Playwright visual regression baselines committed; CI gate green
- [ ] `accesslint/skills@audit` AA contrast gate passing on LP, Executive, Operations paths
- [ ] `.interface-design/system.md` current; design drift review in PR checklist
- [ ] GraphQL p99 < 200ms; ClickHouse dashboard queries p95 < 2s

**Phase 5 outputs are strict dependencies for Phase 6.**

---

