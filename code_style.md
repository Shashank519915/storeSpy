# Retail Intelligence Platform (RIP) — Engineering Governance & Code Style

**Version:** 1.0.0  
**Status:** Mandatory — All PRs must comply  
**Authority:** Document A (`gml5turbo-srs-tdd.md`) is canonical. Document B is supplementary only.

---

## 1. Purpose & Scope

This document is the **law** for all engineers contributing to RIP. It governs repository layout, polyglot conventions, event schema rules, observability, security, and testing. Non-compliance blocks merge. No exceptions for "quick fixes" or "temporary" shortcuts.

RIP competes with Standard AI, Trigo, and Amazon Just Walk Out. Every line of code must reflect production-grade distributed-systems engineering — not MVP prototypes.

---

## 2. Repository Structure (Turborepo Monorepo)

### 2.1 Root Layout

```
rip/
├── apps/
│   ├── portal/                    # Next.js 15 App Router admin portal
│   ├── api-gateway/               # Go API gateway (GraphQL + REST)
│   ├── lp-engine/                 # Go/Python LP HMM + Fuzzy Logic DAG
│   ├── checkout-verification/     # Go DTW reconciliation engine
│   ├── session-reconstruction/    # Go session state + rehydration
│   ├── spatial-query/             # Go PostGIS spatial enrichment
│   ├── twin-api/                  # Go Digital Twin mutation API
│   ├── reid-service/              # Python Qdrant ReID fusion service
│   ├── event-injector/            # Go QA synthetic event injector
│   └── llm-gateway/               # Python RAG / NL analytics proxy
├── services/
│   ├── edge/
│   │   ├── ingestor/              # Rust/Go FFmpeg NVDEC wrapper
│   │   ├── cv-orchestrator/       # Python Triton pipeline orchestrator
│   │   ├── state-publisher/       # Go Kafka/Redis Streams publisher
│   │   ├── edge-bridge/           # Go Redis Streams → Kafka forwarder
│   │   ├── pos-agent/             # Go POS webhook/serial dongle adapter
│   │   ├── hls-transcoder/        # Go WebRTC/HLS/MJPEG edge streaming
│   │   └── anonymizer/            # Python CUDA face-blur pre-egress
│   └── sim/
│       ├── matrix-engine/         # Unity/Blender synthetic scenario DSL
│       └── replay-driver/         # Go Kafka Parquet replay tool
├── packages/
│   ├── proto/                     # Protobuf schemas + buf codegen
│   ├── opa-policies/              # Rego ABAC policy bundles
│   ├── ts-config/                 # Shared TypeScript strict config
│   ├── ui/                        # Radix + Tailwind shared components
│   ├── spatial-math/              # TypeScript homography + raycast utils
│   └── python-common/             # Pydantic models, OTel, logging
├── infra/
│   ├── terraform/
│   │   ├── modules/               # VPC, EKS, MSK, RDS, S3-WORM, Vault
│   │   └── environments/          # dev, staging, prod
│   ├── helm/
│   │   ├── charts/                # Per-service Helm charts
│   │   └── values/                # Environment overlays (Kustomize-compatible)
│   ├── ansible/                   # Edge bare-metal: drivers, K3s bootstrap
│   └── argocd/                    # ApplicationSets, AppProjects, sync policies
├── edge/
│   ├── k3s-manifests/             # Edge-specific K8s overlays
│   ├── fleet-crds/                # StoreCustomResource definitions
│   └── gpu-operator/              # NVIDIA GPU Operator + DCGM values
├── ml/
│   ├── training/                  # PyTorch training only (never production infer)
│   ├── triton-model-repo/         # TensorRT engines + config.pbtxt
│   ├── golden-datasets/           # LFS-tracked annotated clips (metadata only in git)
│   └── mlflow/                    # Model registry manifests
├── docs/
│   ├── adr/                       # Architecture Decision Records
│   └── runbooks/                  # SRE operational runbooks
├── turbo.json
├── nx.json                        # Nx project graph (complements Turborepo)
├── buf.yaml                       # Protobuf lint + breaking change detection
└── .github/
    └── workflows/                 # CI: lint, test, Trivy, GPU golden, chaos
```

### 2.2 Bounded Context Rules

| Context | Languages | Forbidden Cross-Imports |
|---------|-----------|---------------------------|
| Edge CV | Rust/Go (ingest), Python (infer) | Must not import cloud business logic |
| Event Backbone | Go (bridge, consumers) | Must not import UI or CV training code |
| Cloud Reasoning | Go + Python (LP math) | Must not import FFmpeg or CUDA bindings |
| Portal | TypeScript only | Must not import Python/Go source directly |
| Infrastructure | HCL, YAML, Rego | No application runtime code |

### 2.3 Naming Conventions

- **Services:** `kebab-case` directories; K8s Deployment names match directory name.
- **Kafka topics:** `<domain>.<entity>.<event-type>` — e.g., `vision.interaction.product-picked-up`.
- **Protobuf packages:** `rip.<domain>.v<major>` — e.g., `rip.vision.v1`.
- **PostgreSQL schemas:** `identity`, `retail`, `twin` — never `public` for app tables.
- **Redis keys:** `<entity>:<store_id>:<resource_id>` — e.g., `session:store_01:sess_abc`.
- **Vault paths:** `secret/data/rip/<env>/<service>/<key>` — never hardcoded secrets.

### 2.4 Dependency Management

- **Go:** `go.mod` per service; shared libs only in `packages/go-common` (if created). Pin via `go.sum`. Use `go.work` at root for local dev.
- **Python:** `uv` or `poetry` lockfiles per service. `mypy` strict in CI. No unpinned `pip install` in Dockerfiles.
- **TypeScript:** `pnpm` workspaces. Single root `pnpm-lock.yaml`. No `npm` or `yarn`.
- **Protobuf:** `buf` for lint, format, breaking-change detection. Generated code is committed **only** for TypeScript portal consumption; Go/Python use CI codegen.

---

## 3. Polyglot Paradigms & Linting

### 3.1 Go

**Formatter:** `gofmt` + `goimports` — enforced in pre-commit and CI.

**Linter:** `golangci-lint` with minimum enabled linters:
`errcheck`, `gosimple`, `govet`, `staticcheck`, `unused`, `ineffassign`, `typecheck`, `gocritic`, `revive`, `bodyclose`, `noctx`, `wrapcheck`.

**Mandatory patterns:**
- **Interface segregation:** Accept interfaces, return structs. Interfaces live in consumer packages, not provider packages.
- **Error wrapping:** Always `fmt.Errorf("context: %w", err)`. Never return naked errors across package boundaries.
- **Context propagation:** Every exported function accepting I/O or RPC takes `context.Context` as first parameter. Extract `trace_id`/`span_id` from OTel span context; inject into Kafka headers and structured logs.
- **No panics in services:** `panic` is forbidden in `main` goroutines outside startup fatal config errors. Use explicit error returns + DLQ routing.
- **Concurrency:** Document goroutine ownership. Use `errgroup` for fan-out. Always respect `ctx.Done()`.

**Forbidden:**
- `fmt.Println`, `log.Print` — use structured logger (see §5).
- Global mutable state without `sync.RWMutex` or atomic types.
- Direct Kafka publish without Outbox pattern (cloud services).

### 3.2 Python

**Formatter:** `black` (line length 100).

**Linter:** `ruff` with `E`, `F`, `I`, `N`, `UP`, `B`, `C4`, `SIM`, `TCH` rules.

**Type checking:** `mypy --strict`. **`Any` is forbidden** except in explicitly annotated shim files approved via ADR.

**Data validation:** All external input (Kafka payloads, HTTP bodies, config files) validated through **Pydantic v2** models. No raw `dict` access on untrusted data.

**CV pipeline specifics:**
- Training code lives in `ml/training/` only.
- Production inference calls Triton gRPC client only — never `torch.load` in edge containers.
- GPU memory: pre-allocated tensor pools at startup; no per-frame `cudaMalloc`.

**Forbidden:**
- `print()` — use `structlog` JSON logger.
- Bare `except:` clauses.
- `# type: ignore` without linked issue ID.

### 3.3 TypeScript / Next.js

**Compiler:** `strict: true`, `noUncheckedIndexedAccess: true`, `exactOptionalPropertyTypes: true`.

**Imports:** Absolute imports via `@/` alias mapping to `apps/portal/src/`. No relative imports crossing more than one directory level.

**Components:**
- **Functional components only.** No class components.
- **Server Components by default.** `'use client'` only for: R3F canvas, video player, WebSocket hooks, Zustand stores.
- **State separation:** Server state → TanStack Query. Ephemeral UI → Zustand. No Redux.

**Hooks:**
- Custom hooks in `apps/portal/src/hooks/`. One hook per concern (`useLiveTracklets`, `useSyncedVideoPlayer`).
- WebSocket subscriptions isolated in `useRealtimeChannel` — never inline in page components.

**Styling:** Tailwind utility classes only. No CSS-in-JS. Theme tokens via CSS variables (`--rip-primary`, etc.) injected by middleware for white-labeling.

**Forbidden:**
- `console.log` / `console.error` in production paths — use `pino` structured logger.
- `any` type — use `unknown` + type guards.
- Direct ClickHouse queries from client components.

### 3.4 Rust (Edge Ingestor)

Used for FFmpeg NVDEC/CUVID wrapper where Go/Python overhead is unacceptable.

- `rustfmt` + `clippy` with `-D warnings`.
- `thiserror` for error types; no `unwrap()` in library code.
- CUDA bindings via `cudarc` or FFI to C++ shim; pinned memory ring buffer documented in ADR.

### 3.5 C++/CUDA (Optional Performance Shims)

- CUDA kernels in `services/edge/ingestor/native/`.
- Compiled in Docker builder stage; only `.so` copied to runtime image.
- Nsight Compute profiling required before merge for new kernels.

---

## 4. Event Sourcing & Schema Rules

### 4.1 Event Naming

- **Past tense, domain-prefixed:** `ProductPickedUp`, `SessionEnded`, `TwinLayoutChanged`, `TheftAlertTriggered`.
- **Forbidden:** Present tense (`PickProduct`), imperative (`Pick`), ambiguous (`Update`).

### 4.2 Protobuf Schema Definitions

- All Kafka payloads are **Protobuf** (not JSON in production topics). POS edge adapters may ingest JSON but must normalize to Protobuf before cloud Kafka.
- Schema files live in `packages/proto/rip/<domain>/v1/*.proto`.
- Every event message includes:

```protobuf
message EventEnvelope {
  string event_id = 1;          // UUIDv7, time-ordered
  string trace_id = 2;          // W3C trace ID
  string span_id = 3;
  google.protobuf.Timestamp occurred_at = 4;
  google.protobuf.Timestamp ingested_at = 5;
  string store_id = 6;
  string session_id = 7;        // Partition key for business events
  string schema_version = 8;
  // payload oneof below
}
```

### 4.3 Schema Registry & Compatibility

- **Confluent Schema Registry** (or AWS Glue Schema Registry with Protobuf support).
- Compatibility mode: **BACKWARD_TRANSITIVE** for consumers; producers must not break existing consumers.
- **Rules:**
  - Fields are never deleted — mark `deprecated = true` and reserve field numbers.
  - New required fields must have explicit defaults or remain `optional`.
  - Renaming = add new field + deprecate old; never reuse field numbers.
  - Enum values only appended; never renumbered.
- **CI gate:** `buf breaking --against main` must pass before merge to `packages/proto/`.

### 4.4 Partitioning & Ordering

- Business logic topics: partition key = `session_id` (not `store_id` alone — avoids hot partitions while preserving per-session ordering).
- High-volume telemetry (`vision.tracking.tracklet-updated`): partition key = `camera_id`; consumers must tolerate out-of-order via timestamp buffer windows.
- Idempotency: every consumer checks `event_id` against Redis SET with 24h TTL before side effects.

### 4.5 Outbox Pattern (Mandatory for Stateful Producers)

Services with local DB state **never** publish directly to Kafka:
1. Write business row + `outbox` row in single PostgreSQL transaction.
2. Debezium CDC reads `outbox`, publishes to Kafka.
3. Outbox relay marks `published_at` after broker ACK.

---

## 5. Logging, Tracing & Errors

### 5.1 Structured JSON Logging (Mandatory)

All services emit **JSON to stdout**. Required fields:

| Field | Type | Description |
|-------|------|-------------|
| `timestamp` | ISO8601 UTC ms | Event time |
| `level` | string | `debug`, `info`, `warn`, `error` |
| `service_name` | string | K8s deployment name |
| `trace_id` | string | W3C trace ID |
| `span_id` | string | W3C span ID |
| `message` | string | Human-readable summary |
| `metadata` | object | Domain-specific context |

**Forbidden globally:** `fmt.Println`, `print()`, `console.log`, `log.Printf` without JSON wrapper.

### 5.2 Distributed Tracing

- **W3C Trace Context** (`traceparent` header) on all HTTP/gRPC.
- **Kafka headers:** `trace_id`, `span_id` on every message (Confluent header propagation).
- **OpenTelemetry SDK** in Go, Python, TypeScript. Export OTLP to collector — no vendor-specific agents.
- Span naming: `<service>.<operation>` — e.g., `ingestor.decode_frame`, `lp-engine.evaluate_hypothesis`.

### 5.3 Error Handling & Graceful Degradation

- **Edge services:** On GPU OOM → emit `DegradedMode` event, drop to IoU-only tracking, never crash pod.
- **Consumers:** On processing failure → staged retry (`retry-1` 5s, `retry-2` 30s, `retry-3` 5m) → DLQ. **Never** infinite retry blocking partition.
- **DLQ alert:** Any DLQ depth > 0 for > 5 minutes triggers P2 alert.
- **HTTP APIs:** Return RFC 7807 `application/problem+json` errors with `trace_id` in body.

---

## 6. Security Standards

### 6.1 Secrets

- **No raw secrets** in git, Dockerfiles, Helm values committed to repo, or CI logs.
- **HashiCorp Vault** is the sole secrets store.
- Reference secrets in K8s via **Vault Agent Injector** or **External Secrets Operator** with paths:
  - `secret/data/rip/<env>/postgres/<role>`
  - `secret/data/rip/<env>/kafka/<cluster>`
  - `secret/data/rip/<env>/edge/<store_id>/rtsp`
- **Dynamic secrets:** DB credentials TTL ≤ 1 hour, generated at pod startup via K8s SA JWT auth.

### 6.2 Authentication & Authorization

- **Human users:** OIDC via enterprise IdP (Okta/Azure AD). MFA enforced. No custom password DB.
- **Service-to-service:** mTLS via **SPIFFE/SPIRE** on edge; Vault PKI in cloud. Short-lived JWTs (15 min) for gRPC.
- **Authorization:** **OPA sidecar** on API gateway. Rego policies in `packages/opa-policies/`. RBAC coarse roles + ABAC attributes (`store_ids`, `region_ids`).
- **Forbidden:** Long-lived API keys, shared service accounts across environments.

### 6.3 PII & Edge Anonymization

- **Rule:** Raw PII never egresses edge to cloud.
- Frames written to S3/Kafka pass through CUDA anonymization filter (face detection + Gaussian blur) **before** persistence.
- ReID embeddings in Qdrant: TTL 60s for `active_tracklets`; purge on `ForgetMe` command from Opt-Out Zones.
- **Crypto-shredding:** `session_id` and `employee_id` encrypted with per-tenant AEAD keys in Vault before event bus write. RTBF = key deletion, not row DELETE.

### 6.4 Network

- Edge nodes: **outbound-only** WireGuard tunnel to cloud. No inbound public IPs.
- K8s **NetworkPolicies:** CV pods → Kafka only; CV pods ✗ PostgreSQL.
- **Istio/Linkerd** service mesh: mTLS STRICT mode in production.

### 6.5 Evidence Integrity

- Evidence packages: SHA-256 hash → immutable audit log → S3 Object Lock (WORM).
- Audit log service: INSERT-only, no UPDATE/DELETE.

---

## 7. Testing Standards

### 7.1 TDD Mandate

- **Red-Green-Refactor** for all business logic (LP DAG, DTW matcher, spatial queries, session rehydration).
- PRs without tests for new logic are rejected.
- Test file naming: `<module>_test.go`, `test_<module>.py`, `<Component>.test.tsx`.

### 7.2 Coverage Thresholds

| Layer | Minimum Coverage | Tool |
|-------|------------------|------|
| Go services | 80% line | `go test -cover` |
| Python (non-CV) | 80% line | `pytest-cov` |
| Python CV orchestration | 70% line (GPU paths exempt with ADR) | `pytest-cov` |
| TypeScript portal | 75% line | `vitest --coverage` |
| Rego policies | 100% rule path | `opa test` |

### 7.3 Mocking Rules

| Dependency | Mock Strategy |
|------------|---------------|
| Kafka | `testcontainers-go` / `pytest-kafka` with real broker in CI; unit tests use interface mocks recording published messages |
| Redis | `miniredis` (Go), `fakeredis` (Python), `ioredis-mock` (TS) — must simulate TTL and SET NX |
| PostgreSQL | `testcontainers` with PostGIS extension; migrations applied in fixture |
| Qdrant | `testcontainers` Qdrant image; mock only for pure math unit tests |
| GPU / Triton | **Never mock in integration tests.** CI GPU runners execute against real Triton + TensorRT. Unit tests mock gRPC stub responses from recorded fixtures. |
| S3/MinIO | `testcontainers` MinIO with Object Lock enabled |
| Vault | `vault test` dev server in CI; `@hashicorp/vault-client-mock` only for pure unit tests |

### 7.4 Golden Dataset & Determinism

- Golden clips in MinIO; metadata manifests in `ml/golden-datasets/`.
- CI sets `CUBLAS_WORKSPACE_CONFIG=:4096:8` and `torch.use_deterministic_algorithms(True)`.
- Event vector comparison with fuzzy temporal matcher (±500ms, ±0.02 confidence).

### 7.4 Integration & E2E

- **Event Injector** tests: LP and Checkout logic without GPU.
- **Playwright** E2E: login → LP triage → disposition → audit log verification.
- **Synthetic Matrix Engine:** DSL scenarios in CI for CV regression (5-min scenario per CV PR).

### 7.5 Chaos & Load (Staging Gate)

- Chaos Mesh scenarios required before major releases: network partition edge↔cloud, GPU OOM, poison pill message, NTP skew.
- k6 load: 50,000 events/sec × 4 hours; consumer lag < 50ms.

---

## 8. CI/CD Quality Gates

Every PR must pass:

1. Lint + format (language-specific)
2. Unit + integration tests with coverage thresholds
3. `buf lint` + `buf breaking`
4. `opa test` + `conftest` on Helm manifests
5. Trivy scan — **Critical/High CVEs block merge**
6. `terraform plan` review for infra PRs
7. Golden dataset event-diff (CV PRs only)
8. Event injection suite (LP/Checkout PRs)

---

## 9. Documentation Requirements

- **ADR required** for: new database technology, partition key changes, schema breaking changes, new external dependency > 1MB.
- **Runbook required** for: new Kafka topic, new alert rule, new Vault path pattern.
- Public API changes: update OpenAPI/GraphQL schema + portal TypeScript types in same PR.

---

## 10. Code Review Checklist

Reviewers must verify:

- [ ] No secrets, `console.log`, `print`, or `fmt.Println`
- [ ] `trace_id` propagated across boundaries
- [ ] Protobuf schema backward-compatible
- [ ] OPA policy updated if auth scope changes
- [ ] PII anonymized at edge before egress
- [ ] DLQ + retry path exists for new consumers
- [ ] Tests meet coverage thresholds
- [ ] No MVP shortcuts (direct JSON-to-Kafka, raw ffmpeg CLI from Node, etc.)

---

**End of Governance Document**
