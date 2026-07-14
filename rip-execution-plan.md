# RIP Hyper-Granular Execution Plan
**Authority:** Document A (`gml5turbo-srs-tdd.md`)  
**Governance:** `code_style.md`  
**Status:** Complete — split into standalone phase files at `docs/plans/`. Use phase files for day-to-day execution; keep this file as the master reference.

---

# Phase 0: Foundation & Infrastructure as Code

## Phase Objective
Establish the immutable engineering foundation — monorepo skeleton, cloud VPCs, K8s control planes (EKS + K3s reference), Vault HA, SPIFFE/SPIRE identity, CI/CD pipelines, and GitOps — such that every subsequent subsystem deploys into a governed, observable, zero-trust environment. No application logic ships in this phase; only platform primitives.

## Sub-systems Involved
- Turborepo/Nx monorepo (`rip/`)
- Cloud VPC + EKS control plane
- Reference K3s edge cluster (lab)
- HashiCorp Vault HA + PKI mounts
- SPIFFE/SPIRE on edge reference node
- ArgoCD (cloud) + Fleet/ArgoCD Edge agent pattern
- GitHub Actions OIDC → AWS IAM
- OpenTelemetry Collector (daemonset skeleton)
- Terraform remote state (Terraform Cloud)
- Ansible bare-metal edge provisioning playbooks

---

## Granular Tasks

### 0.1 Monorepo Bootstrap
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-0-001 | Initialize Turborepo + pnpm workspaces + Nx project graph with cache keys per language | `turbo.json`, `nx.json`, `pnpm-workspace.yaml` |
| RIP-0-002 | Scaffold directory tree per `code_style.md` §2.1 with placeholder README stubs | `apps/`, `services/`, `packages/`, `infra/` |
| RIP-0-003 | Configure `buf.yaml` with `FILE` breaking rules, `DEFAULT` lint; wire `buf generate` for Go/Python/TS | `packages/proto/buf.yaml` |
| RIP-0-004 | Add shared `packages/ts-config/tsconfig.strict.json` with `strict`, `noUncheckedIndexedAccess` | `packages/ts-config/` |
| RIP-0-005 | Add `.github/workflows/ci-foundation.yml`: lint matrix (golangci-lint, ruff, eslint), `buf lint` | `.github/workflows/` |
| RIP-0-006 | Configure pre-commit hooks: gofmt, black, ruff, eslint, buf format | `.pre-commit-config.yaml` |
| RIP-0-007 | Create ADR template and first ADR: "Turborepo + Nx dual orchestration rationale" | `docs/adr/0001-monorepo-tooling.md` |

### 0.2 Terraform Cloud Foundation
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-0-010 | Terraform Cloud workspace per environment (`rip-dev`, `rip-staging`, `rip-prod`) with remote state locking | Terraform Cloud config |
| RIP-0-011 | Module `infra/terraform/modules/vpc`: multi-AZ VPC, public/private/database subnets, NAT GW, VPC flow logs → S3 | `modules/vpc/` |
| RIP-0-012 | Module `infra/terraform/modules/eks`: EKS 1.29+, managed node groups (system + workload), IRSA enabled | `modules/eks/` |
| RIP-0-013 | Module `infra/terraform/modules/security-baseline`: AWS Config, GuardDuty, CloudTrail → centralized S3 | `modules/security-baseline/` |
| RIP-0-014 | Environment `infra/terraform/environments/dev`: compose VPC + EKS + baseline; CIDR planning doc | `environments/dev/` |
| RIP-0-015 | IAM OIDC provider for GitHub Actions; role `rip-ci-deploy` with least-privilege ECR push + read-only TF plan | `modules/iam-github-oidc/` |
| RIP-0-016 | S3 buckets: `rip-terraform-state` (versioned), `rip-container-registry-mirror`, `rip-edge-image-staging` with encryption + bucket policies | `modules/s3-foundation/` |

### 0.3 Vault HA & PKI
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-0-020 | Deploy Vault HA on EKS via Helm (3 replicas, Raft storage, auto-unseal via AWS KMS) | `infra/helm/charts/vault/` |
| RIP-0-021 | Configure Vault namespaces: `rip/dev`, `rip/staging`, `rip/prod` | Vault policy HCL files |
| RIP-0-022 | Enable Vault PKI engine: intermediate CA `rip-internal-ca`, TTL 24h for service certs | `infra/terraform/modules/vault-pki/` |
| RIP-0-023 | Enable Vault Database Secrets Engine for PostgreSQL dynamic creds (1h TTL) | `infra/terraform/modules/vault-database/` |
| RIP-0-024 | Configure Vault Kubernetes auth: per-service roles bound to K8s SA JWT | `infra/helm/charts/vault-auth/` |
| RIP-0-025 | Deploy External Secrets Operator; `ClusterSecretStore` pointing to Vault | `infra/helm/charts/external-secrets/` |
| RIP-0-026 | Document Vault path convention in runbook | `docs/runbooks/vault-paths.md` |

### 0.4 Kubernetes Platform Services (Cloud EKS)
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-0-030 | Install Istio service mesh: STRICT mTLS PeerAuthentication default-deny | `infra/helm/values/istio/` |
| RIP-0-031 | Deploy ArgoCD with AppProject per bounded context (`portal`, `api`, `reasoning`, `infra`) | `infra/argocd/` |
| RIP-0-032 | Deploy cert-manager with Vault issuer for internal TLS | `infra/helm/charts/cert-manager/` |
| RIP-0-033 | Deploy OpenTelemetry Collector DaemonSet + Gateway; exporters to Tempo + Loki + Prometheus | `infra/helm/charts/otel-collector/` |
| RIP-0-034 | Deploy Prometheus Operator + Grafana + Alertmanager with PagerDuty integration skeleton | `infra/helm/charts/kube-prometheus-stack/` |
| RIP-0-035 | Deploy Loki (distributed mode) + Tempo for trace storage | `infra/helm/charts/loki/`, `tempo/` |
| RIP-0-036 | Define K8s NetworkPolicy default-deny in `rip-system` namespace; explicit allowlist per service | `infra/helm/charts/network-policies/` |

### 0.5 Edge Reference Cluster (K3s Lab)
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-0-040 | Ansible playbook: OS hardening (swap off, ulimits, chrony PTP), NVIDIA driver 535+, container toolkit | `infra/ansible/edge-bootstrap.yml` |
| RIP-0-041 | Ansible playbook: K3s single-node install with SQLite backend, kubeconfig export | `infra/ansible/k3s-install.yml` |
| RIP-0-042 | Deploy NVIDIA GPU Operator on K3s lab node; verify `nvidia.com/gpu` resource | `edge/gpu-operator/values-lab.yaml` |
| RIP-0-043 | Deploy DCGM Exporter DaemonSet; verify `DCGM_FI_DEV_GPU_UTIL` in Prometheus | `edge/gpu-operator/dcgm-exporter.yaml` |
| RIP-0-044 | Deploy SPIRE Server (cloud) + SPIRE Agent (edge); issue SVID for `spiffe://rip.internal/edge/lab/store-00` | `infra/helm/charts/spire/` |
| RIP-0-045 | WireGuard outbound tunnel: edge lab → cloud bastion; no inbound edge ports | `infra/ansible/wireguard-edge.yml` |
| RIP-0-046 | Deploy lightweight ArgoCD agent or Rancher Fleet agent on edge; GitOps reconcile loop | `edge/fleet-crds/agent-install.yaml` |

### 0.6 CI/CD Pipeline Foundation
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-0-050 | GitHub Actions: OIDC assume `rip-ci-deploy` role; ECR repository per service skeleton | `.github/workflows/build-push.yml` |
| RIP-0-051 | Multi-stage Docker base image: `nvidia/cuda:12.1-runtime-ubuntu22.04` + OTel + non-root user | `infra/docker/base-cv-runtime/` |
| RIP-0-052 | Trivy scan gate: Critical/High CVE blocks merge | `.github/workflows/security-scan.yml` |
| RIP-0-053 | ArgoCD ApplicationSet for `apps/*` (sync wave 0 = infra, wave 1 = platform, wave 2 = apps) | `infra/argocd/applicationsets/` |
| RIP-0-054 | Conftest policies: forbid `latest` image tags, forbid secret literals in manifests | `infra/helm/policies/` |

---

## Infrastructure/DevOps Tasks (Phase 0)

| Asset | Technology | Specification |
|-------|------------|---------------|
| VPC | Terraform `modules/vpc` | 3 AZ, /16 cloud CIDR, private EKS subnets, DB subnet group |
| EKS | Terraform `modules/eks` | K8s 1.29, managed NG (m6i.xlarge system, m6i.2xlarge workload) |
| Vault | Helm + KMS auto-unseal | 3-node Raft, audit log → S3 |
| Istio | Helm | STRICT mTLS, ingress gateway for portal only |
| ArgoCD | Helm | SSO via OIDC, repo-creds via Vault |
| K3s Lab | Ansible | Single NVIDIA IGX/RTX node reference image |
| SPIRE | Helm | X.509 SVID rotation 1h |
| OTel | DaemonSet + Gateway | OTLP gRPC :4317, batch processor |
| WireGuard | Ansible | Edge initiates, cloud accepts, `/etc/wireguard/rip0.conf` |
| S3 | Terraform | Versioned buckets, Object Lock prep for WORM (enabled Phase 6) |

---

## Production-Ready Implementation Details (Phase 0)

### SPIFFE/SPIRE Edge Identity Bootstrap
1. SPIRE Server runs in EKS `rip-system` namespace with upstream Vault PKI integration for federation.
2. Edge K3s node runs SPIRE Agent with join token delivered via Vault one-time secret (never committed).
3. Agent attests node via `k8s_psat` plugin; issues SVID `spiffe://rip.internal/edge/<store_id>/<node_id>`.
4. Edge services present SVID for mTLS to cloud Kafka bridge and Vault Agent auth.
5. Rotation: SVID TTL 1h; agent renews at 80% lifetime; failure emits `spire_renewal_failed` metric → P2 alert.

### GitHub Actions OIDC → AWS (No Long-Lived Keys)
1. Configure AWS IAM OIDC provider for `token.actions.githubusercontent.com`.
2. Role trust policy: `sub` = `repo:org/rip:ref:refs/heads/main` for deploy; `pull_request` for plan-only.
3. CI job `permissions: id-token: write` → `aws-actions/configure-aws-credentials` with role `rip-ci-deploy`.
4. ECR push scoped to `rip/*` repositories only.

### WireGuard Edge Tunnel
1. Cloud bastion generates keypair; public key stored in Vault `secret/data/rip/<env>/wireguard/peers/<store_id>`.
2. Edge Ansible role writes `wg0.conf`: `PersistentKeepalive=25`, `AllowedIPs=10.200.0.0/16` (cloud service CIDR).
3. Kafka MSK brokers reachable only via tunnel SG rule: source = WireGuard peer IPs.
4. Tunnel health: `wireguard_latest_handshake_seconds` exported via node_exporter textfile collector.

---

## Testing & Validation (Phase 0)

| Test | Procedure | Pass Criteria |
|------|-----------|---------------|
| TF Plan | `terraform plan` on dev PR | Zero unexpected destroys; cost estimate within budget |
| Vault HA | Kill 1 Vault pod | Cluster remains unsealed; secret read succeeds |
| Vault Dynamic DB | Request creds via K8s SA | Cred works for PostgreSQL; expires after 1h |
| EKS Node Join | Scale NG +1 | Node Ready < 5 min; CNI pods healthy |
| Istio mTLS | `istioctl authn tls-check` | STRICT between two sample services |
| K3s GPU | `kubectl describe node` | `nvidia.com/gpu: 1` allocatable |
| DCGM | Grafana query | GPU metrics visible within 60s of node boot |
| SPIRE | Edge service fetch X.509 | SVID valid; chain to Vault intermediate CA |
| WireGuard | Drop tunnel 60s | Edge alert fires; auto-reconnect on restore |
| ArgoCD | Push manifest change | Sync within 3 min; drift detection active |
| CI OIDC | Run workflow on PR | ECR login without static keys |
| OTel | Emit test span from sample pod | Trace visible in Tempo within 30s |

---

## Exit Criteria (Phase 0)

- [ ] Monorepo scaffold merged; all CI lint jobs green on empty services
- [ ] `rip-dev` Terraform applied: VPC + EKS + S3 + IAM OIDC operational
- [ ] Vault HA cluster unsealed; dynamic PostgreSQL secrets tested
- [ ] Istio STRICT mTLS enforced cluster-wide
- [ ] ArgoCD syncing `infra/helm/charts/otel-collector` to dev EKS
- [ ] K3s lab node provisioned via Ansible; GPU Operator + DCGM healthy
- [ ] SPIRE issuing edge SVIDs; sample mTLS handshake cloud↔edge succeeds
- [ ] WireGuard tunnel stable ≥ 24h soak test with zero unplanned disconnects > 60s
- [ ] GitHub Actions pushing to ECR via OIDC (no static AWS keys in repo)
- [ ] Grafana dashboards: cluster health + GPU lab node + Vault seal status
- [ ] Runbooks: `vault-paths.md`, `edge-bootstrap.md`, `argocd-sync.md` approved by SRE lead

**Phase 0 outputs are strict dependencies for Phase 1.**

---

---

# Phase 1: The Event Backbone & Data Layer

## Phase Objective
Deploy the immutable event nervous system (Kafka MSK + Schema Registry + Debezium Outbox), edge Redis Streams buffer, and the full polyglot persistence tier (PostgreSQL/PostGIS, ClickHouse ReplacingMergeTree, TimescaleDB hypertables, Qdrant HNSW, Redis Cluster, MinIO erasure-coded). At exit, a synthetic `ProductPickedUp` event can flow edge → cloud → ClickHouse with idempotent deduplication and full trace propagation.

## Sub-systems Involved
- Amazon MSK (cloud) + Strimzi Kafka (edge lab)
- Confluent Schema Registry (Protobuf, BACKWARD_TRANSITIVE)
- Debezium Kafka Connect + Outbox tables
- PostgreSQL 16 + PostGIS 3.4 + PgBouncer
- ClickHouse 24.x (ReplacingMergeTree + Kafka engine + MVs)
- TimescaleDB extension on dedicated PostgreSQL instance
- Qdrant cluster (HNSW, TTL collections)
- Redis Cluster (idempotency, session snapshot prep)
- MinIO distributed (erasure coding, lifecycle rules)
- Edge Redis Streams + `edge-bridge` forwarder (Go)
- Initial Protobuf schemas in `packages/proto/`

---

## Granular Tasks

### 1.1 Protobuf Schema Foundation
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-1-001 | Define `EventEnvelope` wrapper with `event_id` (UUIDv7), `trace_id`, `span_id`, timestamps | `packages/proto/rip/common/v1/envelope.proto` |
| RIP-1-002 | Define `vision.tracking.TrackletUpdated` with `camera_id`, bbox, world_x/y, confidence | `packages/proto/rip/vision/v1/tracking.proto` |
| RIP-1-003 | Define `vision.interaction.ProductPickedUp`, `ProductReturned`, `ConcealmentDetected` | `packages/proto/rip/vision/v1/interaction.proto` |
| RIP-1-004 | Define `retail.pos.TransactionEvent` (ITEM_SCANNED, VOIDED, PAYMENT_COMPLETED) | `packages/proto/rip/pos/v1/transaction.proto` |
| RIP-1-005 | Define `twin.mutations.LayoutChanged`, `CameraPitchChanged`, `ShelfMoved` | `packages/proto/rip/twin/v1/mutations.proto` |
| RIP-1-006 | Define `lp.engine.HypothesisUpdated`, `InvestigationTaskCreated` | `packages/proto/rip/lp/v1/engine.proto` |
| RIP-1-007 | Register all schemas in Schema Registry via `buf push` CI step | `.github/workflows/schema-registry.yml` |
| RIP-1-008 | Codegen: Go (`buf generate --template buf.gen.go.yaml`), Python, TypeScript | `packages/proto/buf.gen.*.yaml` |

### 1.2 Cloud Kafka (MSK) + Schema Registry
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-1-010 | Terraform module `msk`: 3-broker cluster, TLS in-transit, IAM + mTLS auth | `infra/terraform/modules/msk/` |
| RIP-1-011 | Topic provisioning (Terraform or Strimzi): all domain topics with RF=3, min.insync.replicas=2 | `infra/terraform/modules/msk-topics/` |
| RIP-1-012 | Partition strategy: business topics 24 partitions; telemetry `tracklet-updated` 96 partitions keyed by `camera_id` | Topic config docs |
| RIP-1-013 | Deploy Confluent Schema Registry on EKS; BACKWARD_TRANSITIVE compatibility | `infra/helm/charts/schema-registry/` |
| RIP-1-014 | Configure MSK ↔ Schema Registry Serde for Protobuf with schema ID header | `docs/runbooks/kafka-serde.md` |
| RIP-1-015 | Create DLQ + retry topics for each consumer domain (`*.retry-1`, `*.retry-2`, `*.retry-3`, `*.dlq`) | `infra/terraform/modules/msk-topics/dlq.tf` |
| RIP-1-016 | Kafka ACLs: per-service principal via IAM/mTLS; deny `WRITE` to `*.dlq` except consumer services | `infra/terraform/modules/msk-acls/` |

### 1.3 Edge Kafka + Redis Streams
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-1-020 | Deploy Strimzi Kafka single-broker K3s (persistent PV on NVMe) for edge lab | `edge/k3s-manifests/kafka-edge.yaml` |
| RIP-1-021 | Deploy Redis 7 on K3s edge (StatefulSet, AOF persistence, 2GB maxmemory allkeys-lru) | `edge/k3s-manifests/redis-edge.yaml` |
| RIP-1-022 | Implement `services/edge/edge-bridge` (Go): XREADGROUP Redis Streams → batch Protobuf → MSK via WireGuard | `services/edge/edge-bridge/` |
| RIP-1-023 | Bridge idempotency: track `last_forwarded_event_id` in Redis HASH; dedupe on reconnect | `edge-bridge/internal/forwarder/` |
| RIP-1-024 | Bridge backpressure: if MSK unreachable, Redis Stream MAXLEN ~ 24h capacity; emit `edge_buffer_pressure` metric | `edge-bridge/internal/backpressure/` |
| RIP-1-025 | Network partition test harness: iptables DROP to MSK for 60s | `services/edge/edge-bridge/test/chaos/` |

### 1.4 Debezium Outbox Pattern
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-1-030 | PostgreSQL `outbox` table: `id`, `aggregate_type`, `aggregate_id`, `event_type`, `payload BYTEA`, `created_at`, `published_at` | `infra/migrations/001_outbox.sql` |
| RIP-1-031 | Deploy Kafka Connect on EKS with Debezium PostgreSQL connector | `infra/helm/charts/kafka-connect/` |
| RIP-1-032 | Debezium Outbox EventRouter transform: route to topic by `event_type` | `infra/helm/charts/kafka-connect/debezium-outbox.json` |
| RIP-1-033 | Sample producer service `apps/event-injector`: write outbox row in TX; verify Kafka message | `apps/event-injector/` |
| RIP-1-034 | Outbox relay lag alert: `outbox_unpublished_count > 100` for > 60s → P2 | Grafana alert rule |

### 1.5 PostgreSQL + PostGIS
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-1-040 | Terraform RDS PostgreSQL 16 Multi-AZ; parameter group: `shared_preload_libraries=pg_stat_statements` | `infra/terraform/modules/rds-postgres/` |
| RIP-1-041 | Enable PostGIS 3.4; create schemas `identity`, `retail`, `twin` | `infra/migrations/002_schemas.sql` |
| RIP-1-042 | Tables: `identity.users`, `identity.tenants`, `identity.roles`, `identity.user_roles` | `infra/migrations/003_identity.sql` |
| RIP-1-043 | Tables: `retail.stores`, `retail.inventory` | `infra/migrations/004_retail.sql` |
| RIP-1-044 | Tables: `twin.store_layouts` (JSONB snapshot), `twin.spatial_objects` (PostGIS geometry) | `infra/migrations/005_twin.sql` |
| RIP-1-045 | GiST index on `twin.spatial_objects.geom`; GIN on `twin.store_layouts.snapshot` | `infra/migrations/006_indexes.sql` |
| RIP-1-046 | Deploy PgBouncer on EKS: transaction pooling, max 200 connections | `infra/helm/charts/pgbouncer/` |
| RIP-1-047 | Vault dynamic creds for `twin-api` SA → `twin` schema only | Vault policy HCL |

### 1.6 ClickHouse OLAP Event Store
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-1-050 | Deploy ClickHouse Operator on EKS; 3-shard 2-replica cluster; ZooKeeper/Keeper | `infra/helm/charts/clickhouse/` |
| RIP-1-051 | Database `analytics`; table `vision_events` ReplacingMergeTree(ingestion_time) | `infra/clickhouse/schemas/vision_events.sql` |
| RIP-1-052 | Partition `toYYYYMM(event_date)`; ORDER BY `(store_id, session_id, event_time, event_type)` | DDL |
| RIP-1-053 | Kafka Engine table consuming `vision.interaction.*` topics; Materialized View → `vision_events` | `infra/clickhouse/schemas/kafka_ingest.sql` |
| RIP-1-054 | Materialized View `heatmap_grid`: aggregate `world_x/world_y` into 0.5m cells hourly | `infra/clickhouse/schemas/heatmap_mv.sql` |
| RIP-1-055 | Idempotency verification: insert duplicate `event_id`; query FINAL; assert single row | `infra/clickhouse/tests/dedup_test.sh` |
| RIP-1-056 | ClickHouse TTL: hot 90 days on cluster; cold tier S3 disk policy (prepare Phase 6) | `infra/clickhouse/schemas/ttl_policy.sql` |

### 1.7 TimescaleDB Infrastructure Metrics
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-1-060 | Deploy TimescaleDB (PostgreSQL 16 + extension) on RDS or dedicated instance | `infra/terraform/modules/rds-timescale/` |
| RIP-1-061 | Hypertable `infra.gpu_metrics` (1s resolution); `infra.kafka_lag` | `infra/migrations/010_timescale.sql` |
| RIP-1-062 | Retention: 7d raw; continuous aggregate 5m rollups → 1y | `infra/migrations/011_timescale_retention.sql` |
| RIP-1-063 | Prometheus remote-write adapter OR OTel metrics exporter → Timescale | `infra/helm/charts/prometheus-timescale-adapter/` |

### 1.8 Qdrant Vector Database
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-1-070 | Deploy Qdrant StatefulSet on EKS; 3 replicas; PVC per node | `infra/helm/charts/qdrant/` |
| RIP-1-071 | Collection `active_tracklets`: 512-dim, Cosine, HNSW `m=16, ef_construct=200` | Qdrant API bootstrap job |
| RIP-1-072 | Collection `product_catalog`: CLIP 768-dim embeddings; no TTL | Bootstrap job |
| RIP-1-073 | TTL policy on `active_tracklets`: purge vectors where `last_seen_timestamp` > 60s stale via scroll + delete job | `apps/reid-service/internal/ttl_purger/` |
| RIP-1-074 | Benchmark: 10k vectors query p99 < 5ms on m6i.2xlarge | `infra/qdrant/benchmarks/` |

### 1.9 Redis Cluster (Cloud)
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-1-080 | Deploy Redis Cluster on EKS (6 nodes, 3 primary 3 replica) OR ElastiCache Serverless | `infra/terraform/modules/elasticache/` |
| RIP-1-081 | Key schema: `idempotency:{event_id}` SET NX EX 86400 | Documentation |
| RIP-1-082 | Key schema: `session:{store_id}:{session_id}` HASH (snapshot prep for Phase 4) | Documentation |
| RIP-1-083 | Redis ACL per service; Vault-dynamic passwords | Vault policy |

### 1.10 MinIO Object Storage
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-1-090 | Deploy MinIO distributed 4-node erasure coding on EKS PVs | `infra/helm/charts/minio/` |
| RIP-1-091 | Buckets: `raw-footage-{store_id}`, `evidence-pkgs`, `ml-artifacts`, `golden-datasets` | MinIO bootstrap job |
| RIP-1-092 | Lifecycle: raw-footage 14d → cold tier; 90d delete unless `legal_hold=true` tag | Bucket policy JSON |
| RIP-1-093 | mTLS between edge and MinIO via WireGuard; SPIFFE cert auth | `docs/runbooks/minio-auth.md` |

### 1.11 Idempotent Consumer Library
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-1-100 | Go package `packages/go-common/kafkaconsumer`: idempotency check, retry/DLQ, trace propagation | `packages/go-common/` |
| RIP-1-101 | Python package `packages/python-common/kafka_consumer`: identical semantics | `packages/python-common/` |
| RIP-1-102 | Consumer interceptors inject `trace_id` from Kafka headers into OTel context | Both packages |
| RIP-1-103 | Staged retry publisher: failure → `retry-1` after 5s delay via scheduled topic | Both packages |

---

## Infrastructure/DevOps Tasks (Phase 1)

| Asset | File / Tool | Detail |
|-------|-------------|--------|
| MSK Cluster | `infra/terraform/modules/msk/main.tf` | kafka.m5.large × 3, TLS, 7-day retention default |
| Schema Registry | Helm values | Protobuf default serde, BACKWARD_TRANSITIVE |
| Debezium | `kafka-connect/debezium-outbox.json` | transforms=Outbox, table=public.outbox |
| ClickHouse | `infra/clickhouse/schemas/*.sql` | ReplicatedReplacingMergeTree on prod |
| PostGIS | `infra/migrations/005_twin.sql` | `geometry(Polygon, 4326)` for zones |
| Qdrant | Helm | 3-node, 100Gi PVC each |
| Redis Cluster | Terraform ElastiCache | Multi-AZ, encryption in-transit |
| MinIO | Helm | 4×500Gi NVMe-backed PV |
| Edge Kafka | Strimzi K3s | 1 broker, 500Gi PV, 24h retention |
| Edge Bridge | K3s Deployment | 2 CPU, 512Mi, WireGuard sidecar |

---

## Production-Ready Implementation Details (Phase 1)

### Debezium Outbox → Kafka Exact Flow
1. Application begins PostgreSQL transaction.
2. Inserts business row (e.g., `twin.store_layouts` new version).
3. Inserts `outbox` row: `event_type='twin.mutations.layout-changed'`, `payload`=Protobuf bytes, `aggregate_id=store_id`.
4. Commits transaction (atomic).
5. Debezium WAL reader detects `outbox` INSERT.
6. Outbox EventRouter extracts `event_type` → topic `twin.mutations.layout-changed`.
7. Message header includes `trace_id` from outbox metadata column (JSON sidecar).
8. Schema Registry validates Protobuf schema ID before broker append.
9. Consumer reads, checks Redis `idempotency:{event_id}` SETNX.
10. If duplicate: ACK and skip. If new: process, SET idempotency key EX 86400.

### ClickHouse ReplacingMergeTree Idempotency
1. Kafka Engine table `vision_events_kafka` consumes binary Protobuf (convert via materialized column).
2. MV `vision_events_mv` INSERT SELECT into `analytics.vision_events`.
3. Engine: `ReplicatedReplacingMergeTree(ingestion_time)`.
4. Duplicate `event_id` with newer `ingestion_time` replaces older on background merge.
5. Investigative queries use `SELECT ... FINAL` or `argMax(payload, ingestion_time) GROUP BY event_id`.
6. Monthly partition drop for retention compliance: `ALTER TABLE DROP PARTITION '202401'`.

### Edge Bridge Backpressure Logic
1. CV services XADD to Redis Stream `edge:events:{store_id}` with MAXLEN ~ 2M (approximate).
2. Bridge consumer group `cloud-forwarder` reads batches of 500 messages.
3. For each message: check MSK connectivity via health probe.
4. If MSK up: produce to MSK with `acks=all`, wait broker ACK, XACK Redis message.
5. If MSK down: stop XACK; messages remain in pending PEL; emit `edge_buffer_depth` gauge.
6. If stream length > 80% MAXLEN: emit `edge_buffer_pressure` P1 alert; CV pipeline receives gRPC backpressure signal to drop raw telemetry (never semantic events).

### Qdrant HNSW ReID Query Path (Prep for Phase 2/4)
1. Query vector: 512-dim OSNet embedding (L2-normalized).
2. Search `active_tracklets` with `filter: store_id = X AND last_seen > now()-60s`.
3. HNSW params: `ef=128` at query time; `score_threshold=0.75` (calibrated per store).
4. Return top-5 candidates with payload `{session_id, camera_id, exit_direction_vector}`.
5. Fusion with spatial-temporal constraints happens in `reid-service` (Phase 4).

---

## Testing & Validation (Phase 1)

| Test | Procedure | Pass Criteria |
|------|-----------|---------------|
| Schema compat | Add optional field to `ProductPickedUp`; produce from v2 producer | v1 consumer deserializes without error |
| Schema reject | Add required field without default; `buf breaking` | CI fails |
| Outbox atomicity | Kill app after DB commit before Kafka visible | Debezium eventually publishes; no orphan DB row without event |
| Idempotency | Replay same `event_id` 100 times | Redis SET prevents duplicate side effects; offset commits |
| Partition order | Send events A, B, C for `session_id=X` | Consumer processes strictly A→B→C |
| ClickHouse dedup | Insert same `event_id` twice | `FINAL` query returns 1 row |
| ClickHouse ingest lag | Produce 10k events/sec for 10 min | MV lag < 5s p99 |
| Edge partition | iptables DROP MSK 60s | Redis Stream retains messages; zero loss on restore; no duplicate in ClickHouse |
| Qdrant latency | 10k vectors, 1000 QPS search | p99 < 5ms |
| PostGIS query | Point-in-polygon for 1000 points | p99 < 2ms with GiST |
| MinIO lifecycle | Upload object; advance clock 15d (test env) | Object transitions to cold tier |
| Trace E2E | Inject event with `trace_id` | Span visible in Tempo across bridge + consumer + ClickHouse insert |

---

## Exit Criteria (Phase 1)

- [ ] All Protobuf schemas registered; `buf breaking` CI green
- [ ] MSK cluster operational; all domain + DLQ topics created with correct partition counts
- [ ] Debezium Outbox publishing `twin.mutations.layout-changed` from sample injector
- [ ] Edge Redis Streams → edge-bridge → MSK path verified with network partition test
- [ ] ClickHouse `vision_events` ingesting from Kafka; ReplacingMergeTree dedup proven
- [ ] `heatmap_grid` MV populating from synthetic `SessionMoved` events
- [ ] PostgreSQL + PostGIS schemas migrated; PgBouncer connection pooling active
- [ ] TimescaleDB hypertables receiving DCGM remote-write metrics
- [ ] Qdrant `active_tracklets` collection operational; benchmark p99 < 5ms
- [ ] Redis Cluster idempotency + session HASH patterns documented and tested
- [ ] MinIO buckets created with lifecycle policies
- [ ] Consumer library (Go + Python) passes idempotency + DLQ unit/integration tests
- [ ] All Phase 1 Grafana alerts configured: DLQ depth, outbox lag, edge buffer pressure, consumer lag
- [ ] Runbook: `kafka-topic-catalog.md`, `clickhouse-schema.md`, `edge-bridge-ops.md`

**Phase 1 outputs are strict dependencies for Phase 2.**

---

---

# Phase 2: Edge CV Pipeline Core

## Phase Objective
Build the production edge perception stack: Rust/Go FFmpeg NVDEC ingestor with CUDA pinned-memory ring buffer, Triton Inference Server with TensorRT engines, BoT-SORT + CMC tracking, 3D homography ground-plane projection, dynamic frame-sampling state machine, and semantic event emission to edge Redis Streams/Kafka. At exit, a live RTSP feed (or synthetic Virtual Camera) produces `ProductPickedUp` events with world coordinates enriched via Digital Twin shelf mapping stubs.

## Sub-systems Involved
- `services/edge/ingestor` (Rust/Go + CUDA FFmpeg)
- `services/edge/cv-orchestrator` (Python Triton client)
- `services/edge/anonymizer` (CUDA face blur pre-egress)
- `services/edge/state-publisher` (Go Protobuf publisher)
- NVIDIA Triton + TensorRT model repository
- BoT-SORT with ECC Camera Motion Compensation
- TransReID / OSNet embeddings (512-dim)
- Homography + pinhole ground-plane projection
- Dynamic frame-sampling state machine (Idle/Active/Interaction)
- Triton dynamic batching (max batch 8, delay 2ms)
- MLflow model registry integration

---

## Granular Tasks

### 2.1 FFmpeg NVDEC Ingestor Service
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-2-001 | Rust/Go service scaffold with CUDA FFI to NVDEC/CUVID decoder | `services/edge/ingestor/` |
| RIP-2-002 | RTSP connection pool: one session per camera; TCP transport; RTP NTP timestamp extraction | `ingestor/src/rtsp/` |
| RIP-2-003 | Exponential backoff reconnection: 1s, 2s, 4s, 8s, 16s, 30s cap; emit `CameraDisconnected` Protobuf | `ingestor/src/reconnect/` |
| RIP-2-004 | CUDA pinned-memory ring buffer: size = `fps × allowed_latency_sec × frame_bytes`; default 30fps × 0.5s | `ingestor/native/ring_buffer.cu` |
| RIP-2-005 | Latest-frame drop policy: if buffer full, overwrite oldest slot; increment `cv_dropped_frames_total` | `ingestor/src/buffer/policy.rs` |
| RIP-2-006 | PTP-synchronized ingest timestamp via chrony; fallback to local monotonic clock | `ingestor/src/timing/` |
| RIP-2-007 | Multi-camera sync window: align frames within 50ms temporal window for overlapping FOV | `ingestor/src/sync/` |
| RIP-2-008 | `IInputSource` trait: RTSP, MP4 file, Virtual Camera (synthetic) adapters | `ingestor/src/sources/` |
| RIP-2-009 | gRPC frame delivery to cv-orchestrator: zero-copy GPU handle + metadata sidecar | `ingestor/proto/frame.proto` |
| RIP-2-010 | Health endpoint: per-camera heartbeat metric `camera_heartbeat_seconds` | `ingestor/src/health/` |

### 2.2 Triton Inference Server Deployment
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-2-020 | Triton Helm chart on K3s with GPU resource limits; model repo PVC | `edge/k3s-manifests/triton.yaml` |
| RIP-2-021 | TensorRT engine: YOLOv8-Pose INT8 (calibration per-store dataset) | `ml/triton-model-repo/yolov8_pose/` |
| RIP-2-022 | TensorRT engine: YOLOv8 product detector (shelf crop secondary) | `ml/triton-model-repo/yolov8_product/` |
| RIP-2-023 | TensorRT engine: OSNet ReID 512-dim FP16 | `ml/triton-model-repo/osnet_reid/` |
| RIP-2-024 | TensorRT engine: ST-GCN or X3D HOI classifier (PICKUP/RETURN/BROWSE/CONCEAL) | `ml/triton-model-repo/hoi_classifier/` |
| RIP-2-025 | Triton `config.pbtxt`: dynamic batching max_batch_size=8, max_queue_delay_microseconds=2000 | Each model dir |
| RIP-2-026 | CUDA MPS daemon on edge node for multi-model concurrent GPU sharing | `edge/k3s-manifests/nvidia-mps.yaml` |
| RIP-2-027 | Pre-allocated GPU tensor pool at orchestrator startup; no per-frame cudaMalloc | `cv-orchestrator/src/gpu_pool.py` |

### 2.3 CV Pipeline Orchestrator
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-2-030 | Python orchestrator: cascaded perception state machine per camera | `services/edge/cv-orchestrator/` |
| RIP-2-031 | State 1 Idle: 1 FPS detection when empty FOV (motion gate via MOG2 background subtraction) | `orchestrator/sampling/idle.py` |
| RIP-2-032 | State 2 Active: 10-15 FPS when person detected | `orchestrator/sampling/active.py` |
| RIP-2-033 | State 3 Interaction: 25-30 FPS on shelf ROI crop when hand near shelf zone | `orchestrator/sampling/interaction.py` |
| RIP-2-034 | Inference cache: pHash background stability check; reuse static shelf detections | `orchestrator/cache/phash_cache.py` |
| RIP-2-035 | CUDA streams pipeline parallelism: det on stream 0, pose on stream 1 overlapped | `orchestrator/pipeline/streams.py` |
| RIP-2-036 | Priority queue scheduler: interaction tasks preempt idle background scans | `orchestrator/scheduler/priority_queue.py` |
| RIP-2-037 | Triton gRPC client wrapper with OTel spans per model inference | `orchestrator/triton/client.py` |

### 2.4 BoT-SORT Multi-Object Tracking
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-2-040 | BoT-SORT implementation: two-pass association (high + low confidence boxes) | `cv-orchestrator/tracking/botsort/` |
| RIP-2-041 | Kalman filter bbox prediction with improved state vector (width/height velocity) | `tracking/botsort/kalman.py` |
| RIP-2-042 | ECC Camera Motion Compensation between consecutive frames for CMC | `tracking/botsort/cmc_ecc.py` |
| RIP-2-043 | Hungarian assignment via LAPJV for detection-to-track matching | `tracking/botsort/associate.py` |
| RIP-2-044 | Appearance feature extraction via OSNet only on track break / occlusion recovery | `tracking/botsort/reid_fallback.py` |
| RIP-2-045 | Tracklet lifecycle: `TrackStarted`, `TrackUpdated`, `TrackLost` events to Redis Stream | `tracking/events.py` |
| RIP-2-046 | Ghost track state: when occluded behind shelf (per trajectory predictor), maintain tracklet up to N frames | `tracking/ghost_predictor.py` |

### 2.5 3D Homography & Ground Plane Projection
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-2-050 | Homography calibration module: 4+ point correspondences → 3×3 matrix (DLT algorithm) | `cv-orchestrator/spatial/homography.py` |
| RIP-2-051 | Pinhole camera model for angled cameras: extrinsics (height, pitch, roll) → ground plane projection | `spatial/pinhole_ground.py` |
| RIP-2-052 | Project bbox bottom-center pixel → world (X, Y) meters in store coordinate system | `spatial/project.py` |
| RIP-2-053 | Multi-camera fusion: overlapping FOV weighted average by visibility confidence | `spatial/fusion.py` |
| RIP-2-054 | Euclidean distance in world space for HOI: hand-to-product < 0.15m for > 3 frames | `spatial/hoi_distance.py` |
| RIP-2-055 | Load homography matrix from PostgreSQL `twin` stub (Phase 3 full; stub JSON in Phase 2) | `spatial/calibration_loader.py` |

### 2.6 Interaction & Session Event Generation
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-2-060 | Product state machine: `OnShelf` → `InHand` → `InCart` / `Returned` | `orchestrator/interaction/product_fsm.py` |
| RIP-2-061 | 15-frame sliding window; emit only if > 70% frames agree on transition | `interaction/temporal_filter.py` |
| RIP-2-062 | Emit `ProductPickedUp`, `ProductReturned`, `ProductAddedToCart` Protobuf to Redis Stream | `state-publisher/` |
| RIP-2-063 | HOI model trigger: hand keypoint enters shelf ROI → ST-GCN/X3D 1-2s window classification | `interaction/hoi_trigger.py` |
| RIP-2-064 | Emit `ConcealmentDetected` when HOI class = CONCEAL with confidence > threshold | `interaction/concealment.py` |

### 2.7 Edge Anonymization Pipeline
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-2-070 | CUDA RetinaFace or YOLO-face detection on frames destined for S3/evidence | `services/edge/anonymizer/` |
| RIP-2-071 | Gaussian blur + solid box overlay on face regions before any persistence | `anonymizer/blur.cu` |
| RIP-2-072 | Verify: no unblurred face bytes in Kafka payloads or S3 uploads (automated pixel scan test) | `anonymizer/tests/` |

### 2.8 State Publisher & Event Emission
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-2-080 | Go `state-publisher`: consume orchestrator events; wrap in `EventEnvelope` with UUIDv7 | `services/edge/state-publisher/` |
| RIP-2-081 | Inject `trace_id` from OTel context into Kafka/Redis message headers | `state-publisher/internal/otel/` |
| RIP-2-082 | Partition key: `session_id` for semantic events; `camera_id` for raw tracklet telemetry | `state-publisher/internal/router/` |
| RIP-2-083 | Degraded mode: on GPU OOM, emit `DegradedMode` event; fall back to IoU-only tracking | `state-publisher/internal/degraded/` |

### 2.9 Virtual Camera & Golden Dataset Prep
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-2-090 | Virtual Camera driver: read MP4 at specified FPS; identical `IInputSource` interface | `ingestor/src/sources/virtual_camera.rs` |
| RIP-2-091 | Ingest 10 golden dataset clips; store expected event vectors | `ml/golden-datasets/manifests/` |
| RIP-2-092 | CI GPU runner: deterministic mode flags; fuzzy event vector diff (±500ms, ±0.02 conf) | `.github/workflows/cv-golden.yml` |

---

## Infrastructure/DevOps Tasks (Phase 2)

| Asset | Detail |
|-------|--------|
| K3s Triton Deployment | GPU request 1, memory 16Gi, model repo 100Gi NVMe PVC |
| NVIDIA MPS | `nvidia-cuda-mps-control` daemon; `CUDA_MPS_PIPE_DIRECTORY` shared volume |
| Ingestor DaemonSet | 1 pod per camera OR grouped 4 cameras/pod based on GPU VRAM profiling |
| MLflow | Model registry tracking TensorRT artifact URIs in MinIO `ml-artifacts` |
| Edge NetworkPolicy | ingestor → cv-orchestrator gRPC only; publisher → Redis/Kafka only |
| Container images | Multi-stage: devel stage compiles FFmpeg+CUDA; runtime copies `.so` only |

---

## Production-Ready Implementation Details (Phase 2)

### CUDA Pinned-Memory Ring Buffer
1. At startup, allocate `N` frames of pinned host memory + corresponding GPU device buffers via `cudaHostAlloc` + `cudaMalloc`.
2. Ring indices: `head` (ingestor writes), `tail` (orchestrator reads), `size` atomic.
3. On new decoded frame: write to `head % N`; if `(head - tail) >= N`, increment `tail` (drop oldest), emit `cv_dropped_frames_total`.
4. Frame metadata sidecar: `{capture_ts_rtp, ingest_ts_ptp, camera_id, gpu_buffer_handle}`.
5. gRPC to orchestrator passes FD/handle for zero-copy GPU→GPU via CUDA IPC where supported.

### Dynamic Frame Sampling State Machine
1. Per camera, maintain FSM state: `IDLE`, `ACTIVE`, `INTERACTION`.
2. MOG2 motion mask on downscaled frame at 1 FPS in IDLE; transition to ACTIVE on person bbox.
3. ACTIVE: request detection at 15 FPS; pose at 10 FPS; tracking at 30 FPS via IoU on intermediate frames.
4. When wrist keypoint projected into shelf ROI polygon (from twin stub): transition to INTERACTION.
5. INTERACTION: crop shelf ROI; run product detector + HOI at 30 FPS; preempt other cameras' IDLE scans in GPU scheduler priority queue.
6. Timeout: no person for 30s → return to IDLE.

### BoT-SORT + ECC CMC Pipeline
1. Frame t: run YOLO detection → high conf (>0.5) + low conf (0.1-0.5) box sets.
2. ECC algorithm estimates affine warp between frame t-1 and t (camera shake compensation).
3. Apply warp to Kalman-predicted track bbox positions before IoU matching.
4. First association: high-conf detections ↔ confirmed tracks (IoU > 0.3).
5. Second association: low-conf detections ↔ remaining unmatched tracks.
6. Unmatched high-conf → new track. Unmatched tracks → `lost` counter increment.
7. On `lost > 30 frames`: extract OSNet embedding from last clear crop; emit `TrackLost` with embedding to cloud ReID prep topic.
8. Ghost mode: if Digital Twin indicates shelf occlusion at predicted position, suppress `lost` increment; linear extrapolation for up to 45 frames.

### Homography Ground-Plane Projection
1. Calibration: admin provides 4+ point pairs `(u,v)` pixel ↔ `(X,Y)` world meters.
2. Compute H via DLT; store 3×3 matrix in `twin.cameras.homography_matrix` (stub JSON Phase 2).
3. For each person bbox: take bottom-center `(u, v_bottom)`.
4. Apply: `[X, Y, W]^T = H × [u, v, 1]^T`; normalize by W.
5. Angled cameras: if pitch > 15°, use pinhole model with known mount height Z_mount, pitch θ, roll φ:
   - Ray from pixel through camera matrix K⁻¹
   - Intersect ray with ground plane Z=0
   - Output (X, Y) in store frame.
6. Fusion: two cameras see same person → weighted average by detection confidence × visibility (not occluded).

### HOI Temporal Confidence Filter
1. Maintain deque of last 15 frame classifications per (track_id, shelf_id).
2. Each frame: compute 3D hand-to-product distance; if < 0.15m, vote `PICKUP`; HOI model vote weighted 2×.
3. Emit `ProductPickedUp` only if ≥ 11/15 frames (73%) agree.
4. Debounce: minimum 500ms between duplicate events for same (track, shelf).

---

## Testing & Validation (Phase 2)

| Test | Procedure | Pass Criteria |
|------|-----------|---------------|
| Ring buffer overflow | Inject 120 FPS into 30 FPS buffer for 60s | Oldest frames dropped; memory stable (no leak); `cv_dropped_frames_total` increases monotonically |
| RTSP reconnect | Kill RTSP server 30s | Backoff sequence observed; `CameraDisconnected` emitted; auto-recover on restore |
| NTP sync fallback | Block NTP; rely on ingest timestamp | Multi-camera sync within 50ms via fallback clock |
| Triton batching | Burst 8 frames in < 2ms | Single batched inference; latency < 100ms p99 |
| BoT-SORT occlusion | Golden clip with shelf occlusion | ID switch rate < 5% vs annotated ground truth |
| ECC CMC | Shake camera mount in test clip | Without CMC: ID switches > 15%; with CMC: < 5% |
| Homography accuracy | Known floor markers | Projected (X,Y) within ±0.25m of ground truth |
| HOI filter | Inject jittery hand detection | No spurious `ProductPickedUp`; true pickup detected within ±500ms |
| Anonymization | Upload 100 frames to S3 | Automated face pixel scan: zero unblurred face regions |
| Golden dataset CI | 10 clips through pipeline | Event vector F1 ≥ 0.92 vs annotated ground truth |
| GPU OOM injection | stress-ng exhaust VRAM | `DegradedMode` emitted; IoU tracking continues; pod does not crash |
| Trace propagation | Single pickup event | End-to-end trace in Tempo: ingestor → orchestrator → publisher → edge-bridge |

---

## Exit Criteria (Phase 2)

- [ ] Ingestor decoding 4+ RTSP streams (or Virtual Cameras) with NVDEC on K3s lab GPU
- [ ] Ring buffer drop policy verified under 120 FPS stress; zero memory leaks in 24h soak
- [ ] Triton serving YOLOv8-Pose, product detector, OSNet, HOI classifier with TensorRT INT8/FP16
- [ ] Dynamic frame sampling FSM transitioning correctly across Idle/Active/Interaction states
- [ ] BoT-SORT + ECC CMC tracking with ID switch rate < 5% on golden dataset
- [ ] Ground-plane (X,Y) projection operational with homography stub; accuracy ±0.25m
- [ ] `ProductPickedUp`, `ConcealmentDetected` events flowing to edge Redis → MSK → ClickHouse
- [ ] Anonymization verified: no raw faces in S3 or Kafka payloads
- [ ] GPU OOM graceful degradation proven (DegradedMode + IoU fallback)
- [ ] Golden dataset CI gate passing with F1 ≥ 0.92
- [ ] DCGM dashboards: inference latency p99 < 100ms, `cv_dropped_frames_total` monitored
- [ ] MLflow registry tracking all TensorRT engine versions with calibration dataset manifest

**Phase 2 outputs are strict dependencies for Phase 3.**

---

---

# Phase 3: Digital Twin & Spatial Mapping

## Phase Objective
Build the mathematically rigorous spatial substrate: event-sourced Scene Graph DAG in PostgreSQL/PostGIS, spatial query enrichment service, raycasting-based camera coverage and blind-spot estimation, navigation graph for walking-distance reasoning, and time-travel twin versioning. At exit, a CV `HandMoved` coordinate is enriched to `ShelfInteraction(shelf_id, zone, session_id)` via point-in-polygon; camera placement validation renders a blind-spot heatmap; historical twin state is reconstructable at any timestamp.

## Sub-systems Involved
- `apps/twin-api` (Go mutation API + Outbox)
- `apps/spatial-query` (Go PostGIS enrichment)
- PostgreSQL `twin` schema + PostGIS geometry
- Kafka topic `twin.mutations.*`
- Scene Graph DAG (Store → Zone → Aisle → Fixture → Shelf → Facing)
- Navigation graph (waypoints for walking distance)
- Raycasting engine (1° FOV increments, shelf height occlusion)
- Homography calibration API
- `packages/spatial-math` (TypeScript + Go shared math)
- R3F Store Designer (frontend scaffold — full UI in Phase 5; API + math here)

---

## Granular Tasks

### 3.1 Scene Graph Data Model
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-3-001 | Protobuf: `TwinNode`, `TwinEdge`, `SpatialTransform`, `MutationEvent` oneofs | `packages/proto/rip/twin/v1/scene_graph.proto` |
| RIP-3-002 | PostgreSQL `twin.nodes`: `id`, `store_id`, `parent_id`, `node_type`, `transform JSONB`, `metadata JSONB`, `valid_from`, `valid_to` | `infra/migrations/020_twin_nodes.sql` |
| RIP-3-003 | PostgreSQL `twin.edges`: navigation graph edges between waypoint nodes | `infra/migrations/021_twin_edges.sql` |
| RIP-3-004 | PostgreSQL `twin.spatial_objects`: PostGIS `geometry(Polygon)` for zones; `geometry(LineString)` for shelf centerlines | `infra/migrations/022_twin_spatial.sql` |
| RIP-3-005 | PostgreSQL `twin.cameras`: mount `(x,y,z)`, `pan`, `tilt`, `fov_degrees`, `homography_matrix FLOAT[9]`, `twin_version_id` FK | `infra/migrations/023_twin_cameras.sql` |
| RIP-3-006 | PostgreSQL `twin.versions`: `version INT`, `snapshot JSONB`, `valid_from`, `valid_to NULL` for active | `infra/migrations/024_twin_versions.sql` |
| RIP-3-007 | GIN index on `nodes.metadata`; GiST on `spatial_objects.geom` and `cameras.mount_point` | `infra/migrations/025_twin_indexes.sql` |
| RIP-3-008 | Seed reference store layout JSON (lab store) for K3s integration tests | `infra/seeds/twin_lab_store.json` |

### 3.2 Event-Sourced Twin Mutations
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-3-010 | `apps/twin-api`: CRUD mutations as commands → Outbox rows (never in-place UPDATE of geometry) | `apps/twin-api/` |
| RIP-3-011 | Mutation types: `ShelfMoved`, `CameraPitchChanged`, `ZoneAdded`, `SKUAssignedToFacing`, `NavigationEdgeAdded` | `apps/twin-api/internal/commands/` |
| RIP-3-012 | Debezium routes `twin.mutations.*` to Kafka; consumer projects mutations into materialized snapshot | `apps/twin-projector/` |
| RIP-3-013 | Snapshot cadence: update `twin.versions.snapshot` every N mutations or 60s batch window | `twin-projector/internal/snapshotter/` |
| RIP-3-014 | Time-travel API: `GET /api/twin/{store_id}?timestamp=ISO8601` — load nearest snapshot + replay mutations ≤ timestamp | `apps/twin-api/internal/timetravel/` |
| RIP-3-015 | Optimistic concurrency: `expected_version` field on mutation commands; reject stale writes with 409 | `twin-api/internal/commands/versioning.go` |
| RIP-3-016 | Emit `TwinLayoutChanged` to Kafka on every successful mutation batch | `twin-projector/internal/events/` |

### 3.3 Spatial Query Service
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-3-020 | `apps/spatial-query` (Go): consume `vision.interaction.*` with raw `(world_x, world_y)` | `apps/spatial-query/` |
| RIP-3-021 | PostGIS `ST_Contains(zone.geom, ST_SetSRID(ST_MakePoint(x,y), 4326))` for zone classification | `spatial-query/internal/queries/zone.go` |
| RIP-3-022 | Shelf interaction zones: point-in-polygon against `spatial_objects` where `node_type='Shelf'` | `spatial-query/internal/queries/shelf.go` |
| RIP-3-023 | Enrichment transform: `HandMoved` → `ShelfInteraction{shelf_id, zone, session_id}` Protobuf | `spatial-query/internal/enricher/` |
| RIP-3-024 | Checkout zone geofence: emit `EnteredCheckoutZone`, `ExitedCheckoutZone` on boundary crossing with hysteresis (0.3m) | `spatial-query/internal/geofence/checkout.go` |
| RIP-3-025 | Exit gate geofence: emit `ExitGateCrossed` when trajectory crosses `Zone:Exit` polygon | `spatial-query/internal/geofence/exit.go` |
| RIP-3-026 | Opt-Out Zone handler: on `ST_Contains(opt_out.geom, point)`, emit `ForgetMe` command to ReID purge topic | `spatial-query/internal/privacy/optout.go` |
| RIP-3-027 | Cache hot spatial index in Redis: R-tree serialized per `store_id` + `twin_version_id`; invalidate on `TwinLayoutChanged` | `spatial-query/internal/cache/` |

### 3.4 Navigation Graph & Walking Distance
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-3-030 | Build directed graph from `twin.edges` (waypoint nodes on walkable paths) | `spatial-query/internal/navgraph/build.go` |
| RIP-3-031 | Dijkstra shortest path on navigation graph for walking distance (not Euclidean) | `spatial-query/internal/navgraph/dijkstra.go` |
| RIP-3-032 | gRPC `GetWalkingDistance(camera_a_exit, camera_b_entrance)` for ReID travel-time validation | `spatial-query/proto/nav.proto` |
| RIP-3-033 | Average human walking speed constant 1.4 m/s; compute expected Δt min/max with ±30% tolerance | `spatial-query/internal/navgraph/travel_time.go` |
| RIP-3-034 | Expose walking path polyline for LP trajectory evidence packages | `spatial-query/internal/navgraph/path_export.go` |

### 3.5 Raycasting: Camera Coverage & Blind Spots
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-3-040 | Go raycasting engine: cast rays from camera floor projection at 1° increments across `fov_degrees` | `packages/go-common/raycast/` |
| RIP-3-041 | For each ray: intersect shelf/wall polygons considering height profile (shelf `z_max` blocks ray below mount `z`) | `raycast/occlusion_height.go` |
| RIP-3-042 | Unblocked ray endpoints form visible polygon; complement = blind spot regions | `raycast/coverage_polygon.go` |
| RIP-3-043 | Critical zone audit: flag if `Zone:Checkout` or high-value merchandise polygons overlap blind spots > 10% area | `raycast/critical_audit.go` |
| RIP-3-044 | Persist coverage heatmap grid to PostgreSQL `twin.camera_coverage` (JSONB grid) per camera per version | `infra/migrations/026_camera_coverage.sql` |
| RIP-3-045 | API `POST /api/twin/{store_id}/cameras/{id}/coverage/recalculate` triggers async raycast job | `apps/twin-api/internal/coverage/` |
| RIP-3-046 | Emit `BlindSpotIdentified` event when critical zone coverage < threshold | `twin-api/internal/coverage/events.go` |
| RIP-3-047 | LP confidence adjustment hook: blind-spot flag stored on session state (consumed Phase 4) | `twin.camera_coverage.blind_spot_penalty` metadata |

### 3.6 Homography Calibration API
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-3-050 | API `POST /api/twin/{store_id}/cameras/{id}/calibrate` accepts ≥4 point pairs `(pixel_u, pixel_v, world_x, world_y)` | `apps/twin-api/internal/calibration/` |
| RIP-3-051 | DLT homography computation; reprojection error RMS validation (reject if > 0.5m) | `packages/go-common/spatial/homography.go` |
| RIP-3-052 | Pinhole fallback for angled cameras: accept `mount_z`, `pitch`, `roll`, `intrinsic_matrix` | `packages/go-common/spatial/pinhole.go` |
| RIP-3-053 | On success: emit `CameraCalibrated` mutation; push matrix to edge via GitOps `StoreCustomResource` | `twin-api/internal/calibration/publish.go` |
| RIP-3-054 | Shared TS math lib mirror for frontend real-time overlay validation | `packages/spatial-math/homography.ts` |

### 3.7 3D Frustum Projection (Backend Validation)
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-3-060 | Compute 3D camera frustum truncated pyramid from mount pose + FoV | `packages/go-common/spatial/frustum.go` |
| RIP-3-061 | Project frustum base onto Z=0 floor plane → 2D coverage polygon | `spatial/frustum_project.go` |
| RIP-3-062 | Cross-validate frustum polygon vs raycast coverage (area delta < 5%) | `twin-api/internal/coverage/validate.go` |
| RIP-3-063 | Occlusion shadow polygons behind tall fixtures relative to camera | `raycast/occlusion_shadow.go` |

### 3.8 Twin Projector & Edge Sync
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-3-070 | `StoreCustomResource` CRD: `spec.cameras[].homography_matrix`, `spec.shelves[].polygons` | `edge/fleet-crds/store-custom-resource.yaml` |
| RIP-3-071 | Fleet agent watches twin version; rolling update edge cv-orchestrator calibration without pod restart (SIGHUP reload) | `edge/fleet-crds/twin-sync-agent.yaml` |
| RIP-3-072 | Edge spatial-query lightweight cache: subscribe to `twin.mutations.layout-changed`; hot-reload shelf ROIs | `services/edge/cv-orchestrator/spatial/twin_cache.py` |

---

## Infrastructure/DevOps Tasks (Phase 3)

| Asset | Detail |
|-------|--------|
| `twin-api` Deployment | EKS, 3 replicas, PgBouncer, Vault dynamic creds `twin` schema |
| `spatial-query` Deployment | Kafka consumer group `spatial-enricher`, 6 replicas, partition by `store_id` |
| `twin-projector` Deployment | Single leader election via Redis lock; snapshot writer |
| PostGIS upgrade | Ensure `postgis` 3.4+ on RDS parameter group |
| Coverage batch jobs | K8s CronJob nightly recalculate all camera coverage after layout changes |
| Redis cache | `twin:spatial_index:{store_id}:{version}` with 1h TTL, invalidate on mutation |

---

## Production-Ready Implementation Details (Phase 3)

### Raycasting Blind Spot Algorithm (Exact Steps)
1. Load camera node: floor position `(cx, cy)`, mount height `z_cam`, pan `ψ`, tilt `θ`, `fov_degrees = φ`.
2. Compute left/right bearing: `ψ ± φ/2` in floor-plane coordinates.
3. For `bearing` from `ψ - φ/2` to `ψ + φ/2` step 1°:
   - Cast ray from `(cx, cy)` along `bearing` as half-line.
   - For each shelf/wall polygon with height `z_max`:
     - If `z_max < z_cam × tan(elevation_angle)` → ray blocked at intersection point; stop ray.
     - Else ray passes over (shelf shorter than sight line).
   - Record terminal point (wall hit or max range 30m).
4. Triangulate visible region from ray endpoints; compute `visible_area`.
5. `blind_area = sales_floor_polygon - visible_area`.
6. Intersect `blind_area` with critical zones (checkout, high-value SKUs).
7. If `intersection_area / critical_zone_area > 0.10` → `BlindSpotIdentified` with severity score.

### Time-Travel Twin Reconstruction
1. Query `twin.versions` for `store_id` where `valid_from ≤ T` ORDER BY `valid_from DESC LIMIT 1` → snapshot S₀.
2. Fetch Kafka/ClickHouse mutations from `twin.mutations.*` where `occurred_at ∈ (S₀.valid_from, T]`.
3. Apply mutations in `occurred_at` order to in-memory Scene Graph DAG.
4. Return materialized graph; cache result in Redis keyed `(store_id, T)` for 15 min.
5. Historical LP investigation at T uses this graph for spatial context — not current layout.

### Spatial Enrichment Pipeline
1. Consumer receives `vision.interaction.HandMoved{world_x, world_y, session_id}`.
2. Load spatial index for active `twin_version_id` (Redis cache or PostGIS direct).
3. `ST_Contains(shelf.geom, point)` → if match, determine `zone` (left_side/right_side/front) via shelf centerline normal.
4. Emit `vision.interaction.ShelfInteraction{shelf_id, zone, session_id}` with same `trace_id`.
5. Geofence state machine per session in Redis: track `current_zone`; on transition across checkout polygon boundary → emit zone events.

### Walking Distance for ReID (Prep Phase 4)
1. Camera A exit waypoint: nearest navigation graph node to camera A exit ray endpoint.
2. Camera B entrance waypoint: nearest node to camera B entrance.
3. Dijkstra on `twin.edges` weighted by edge length (meters).
4. `distance_m / 1.4 m/s = expected_travel_sec`; tolerance window `[0.7×, 1.3×] × expected_travel_sec`.
5. ReID service rejects candidate matches outside temporal window.

---

## Testing & Validation (Phase 3)

| Test | Procedure | Pass Criteria |
|------|-----------|---------------|
| Point-in-polygon | 10k random points against 50 shelf polygons | p99 < 2ms via GiST; 100% accuracy vs brute-force |
| Shelf enrichment | Inject `HandMoved` at known shelf coordinate | `ShelfInteraction` with correct `shelf_id` and `zone` |
| Geofence hysteresis | Oscillate point on checkout boundary ±0.2m | No flapping; single `EnteredCheckoutZone` |
| Time-travel | Apply 50 mutations; query T mid-sequence | Graph matches manual replay; ≠ current state |
| Optimistic lock | Two concurrent `ShelfMoved` with same `expected_version` | One succeeds; one 409 Conflict |
| Raycast coverage | Known L-shaped store with 1 camera | Blind spot area matches manual CAD within 3% |
| Critical zone flag | Place checkout in blind spot | `BlindSpotIdentified` severity > 0.8 |
| Homography calibrate | 4-point calibration with known error injection | Reject RMS > 0.5m; accept < 0.2m |
| Navigation distance | Compare Dijkstra vs measured tape distance on floor plan | Error < 5% |
| Twin edge sync | Mutate shelf in cloud; wait Fleet reconcile | Edge cv-orchestrator shelf ROI updated < 5 min |
| Opt-Out zone | Track enters opt-out polygon | `ForgetMe` emitted; Qdrant vector purged (Phase 4 integration) |

---

## Exit Criteria (Phase 3)

- [ ] Scene Graph DAG persisted with full hierarchy; lab store seeded
- [ ] All twin mutations event-sourced via Outbox → Kafka → projector → snapshot
- [ ] Time-travel API returns correct layout at historical timestamps
- [ ] Spatial-query enriching `HandMoved` → `ShelfInteraction` in real-time (< 10ms p99)
- [ ] Checkout and exit geofences emitting zone transition events
- [ ] Raycasting coverage + blind-spot heatmap for all cameras in lab store
- [ ] Critical zone blind-spot audit flagging operational
- [ ] Homography calibration API with reprojection validation; matrix synced to edge
- [ ] Navigation graph walking distance API operational
- [ ] Twin version synced to edge `StoreCustomResource` via Fleet GitOps
- [ ] PostGIS spatial query p99 < 2ms at 10k QPS synthetic load

**Phase 3 outputs are strict dependencies for Phase 4.**

---

---

# Phase 4: Cloud Reasoning & State Engines

## Phase Objective
Deploy the cloud intelligence layer: Session Reconstruction with snapshot/rehydration, cross-camera ReID probabilistic fusion (Qdrant + spatial-temporal + Bayesian), Loss Prevention HMM + Fuzzy Logic DAG, Checkout Verification DTW matcher, and evidence package orchestration. At exit, a multi-camera synthetic shoplifting scenario produces a ranked `InvestigationTask` with stitched evidence metadata; a checkout scenario with intentional pass-back produces `Major Discrepancy` via DTW.

## Sub-systems Involved
- `apps/session-reconstruction` (Go)
- `apps/reid-service` (Python + Qdrant)
- `apps/lp-engine` (Go orchestration + Python HMM/Fuzzy math)
- `apps/checkout-verification` (Go DTW)
- `apps/pos-agent` (edge POS ingestion — cloud consumer side)
- Redis session snapshots + idempotency
- ClickHouse event replay for forensic rehydration
- Kafka consumer groups with retry/DLQ
- MinIO evidence package staging
- PIM database integration for multi-pack SKU expansion

---

## Granular Tasks

### 4.1 Session Reconstruction Service
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-4-001 | Consumer `vision.tracking.tracklet-updated` (partitioned by `camera_id`); buffer out-of-order within 200ms window | `apps/session-reconstruction/` |
| RIP-4-002 | Global session ID assignment: merge tracklets via ReID service callback | `session-reconstruction/internal/session/merge.go` |
| RIP-4-003 | Session state machine: `SessionStarted`, `SessionMoved`, `SessionEnded` semantic events | `session-reconstruction/internal/session/fsm.go` |
| RIP-4-004 | Vision cart construction: aggregate `ProductPickedUp` / `ProductReturned` per `session_id` | `session-reconstruction/internal/cart/vision_cart.go` |
| RIP-4-005 | Redis HASH `session:{store_id}:{session_id}`: `current_x/y`, `current_zone`, `vision_cart JSON`, `theft_score`, `last_event_ts` | `session-reconstruction/internal/state/redis.go` |
| RIP-4-006 | Snapshot every 5s or on checkout complete: `session:{session_id}:snapshot` with `snapshot_ts` | `session-reconstruction/internal/snapshot/writer.go` |
| RIP-4-007 | Rehydration: load snapshot + replay Redis Stream buffer / Kafka events after `snapshot_ts` | `session-reconstruction/internal/snapshot/rehydrate.go` |
| RIP-4-008 | Emit `retail.session.session-updated` for downstream LP and Checkout consumers | `session-reconstruction/internal/publisher/` |
| RIP-4-009 | Handle `TrackLost` + `TrackStarted`: invoke ReID merge or new session fork logic | `session-reconstruction/internal/reid/handler.go` |

### 4.2 Cross-Camera ReID Service
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-4-010 | `apps/reid-service` (Python): gRPC `FindCandidates(embedding, store_id, camera_id, timestamp)` | `apps/reid-service/` |
| RIP-4-011 | On `TrackLost`: upsert 512-dim OSNet embedding to Qdrant `active_tracklets` with payload `{session_id, exit_direction, world_x/y, last_seen}` | `reid-service/internal/indexer.py` |
| RIP-4-012 | On new track: query Qdrant top-5 cosine similarity; filter by store + 60s TTL | `reid-service/internal/search.py` |
| RIP-4-013 | Spatial-temporal gate: call `spatial-query` `GetWalkingDistance`; reject if Δt outside [0.7×, 1.3×] expected | `reid-service/internal/fusion/temporal.py` |
| RIP-4-014 | Trajectory projection: Kalman extrapolation from exit vector; score alignment with entrance vector | `reid-service/internal/fusion/trajectory.py` |
| RIP-4-015 | Bayesian fusion: combine visual similarity, temporal score, trajectory score → posterior | `reid-service/internal/fusion/bayesian.py` |
| RIP-4-016 | Merge threshold posterior > 0.85 → return `merged_session_id`; else new session | `reid-service/internal/decision.py` |
| RIP-4-017 | Dynamic per-store similarity threshold calibration from shadow model metrics | `reid-service/internal/calibration/threshold.py` |
| RIP-4-018 | `ForgetMe` handler: delete all vectors for `session_id` in Qdrant | `reid-service/internal/privacy/forget.py` |

### 4.3 Loss Prevention Engine (HMM + Fuzzy Logic DAG)
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-4-020 | `apps/lp-engine` (Go): Kafka consumer `vision.interaction.*`, `retail.session.*`, `retail.pos.*` | `apps/lp-engine/` |
| RIP-4-021 | Suspicion DAG definition: nodes = observable events; edges = conditional transitions | `apps/lp-engine/internal/dag/graph.go` |
| RIP-4-022 | Python sidecar `lp-math`: HMM hidden states (`Shopping`, `Concealing`, `PlanningExit`, `Theft`) | `services/lp-math/hmm.py` |
| RIP-4-023 | Fuzzy Logic controller: fuzzify inputs (occlusion duration, hand-bag intersection, blind-spot traversal) | `services/lp-math/fuzzy.py` |
| RIP-4-024 | Defuzzify → `SuspicionScore` [0.0, 1.0] per `(session_id, sku)` | `services/lp-math/defuzzify.py` |
| RIP-4-025 | Evidence buckets implemented: `MultiplePicksNoCart`, `ConcealmentDetected`, `BlindSpotTraversal`, `ExitGateCrossed`, `CheckoutSkipped` | `lp-engine/internal/evidence/` |
| RIP-4-026 | POS heartbeat monitor: if `POSHeartbeat` absent > 30s → enter `DegradedMode`; suspend checkout-skipped logic | `lp-engine/internal/pos/health.go` |
| RIP-4-027 | Sweethearting detection: correlate cashier `operator_id` session with customer session; detect slide-scan motion pattern | `lp-engine/internal/scenarios/sweethearting.go` |
| RIP-4-028 | Basket switching: ReID identity change + basket density increase in < 20% coverage zone | `lp-engine/internal/scenarios/basket_switch.go` |
| RIP-4-029 | Blind-spot confidence adjustment: multiply suspicion by `(1 - blind_spot_penalty)` from twin coverage data | `lp-engine/internal/scoring/blindspot.go` |
| RIP-4-030 | Threshold > 0.60 → `TheftScoreUpdated`; > 0.85 → `InvestigationTaskCreated` | `lp-engine/internal/alerts/emitter.go` |
| RIP-4-031 | Human feedback consumer: `InvestigationResolved{ConfirmedTheft|FalsePositive|Inconclusive}` adjusts HMM transition weights | `lp-engine/internal/feedback/calibrator.go` |

### 4.4 Evidence Package Orchestration
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-4-040 | On `InvestigationTaskCreated`: instruct edge to upload 15s pre/post buffer clips per observing camera | `lp-engine/internal/evidence/request.go` |
| RIP-4-041 | Edge clip upload to MinIO `evidence-pkgs/{task_id}/`; anonymized by default | `services/edge/state-publisher/evidence_upload.go` |
| RIP-4-042 | Cloud assembler: FFmpeg stitch multi-camera PiP video; overlay bboxes, session ID, suspicion timeline | `apps/evidence-assembler/` |
| RIP-4-043 | Trajectory map generation: query ClickHouse `SessionMoved` + twin walking path | `evidence-assembler/internal/trajectory.go` |
| RIP-4-044 | Event timeline JSON: chronological semantic events for session | `evidence-assembler/internal/timeline.go` |
| RIP-4-045 | POS reconciliation summary attached from checkout-verification state | `evidence-assembler/internal/pos_summary.go` |
| RIP-4-046 | SHA-256 hash of MP4 + timeline JSON → `security.audit_logs` Kafka topic | `evidence-assembler/internal/integrity/hash.go` |

### 4.5 Checkout Verification Engine (DTW)
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-4-050 | `apps/checkout-verification` (Go): trigger on session entering `Checkout Zone` | `apps/checkout-verification/` |
| RIP-4-051 | Reconciliation FSM: `ApproachingCheckout` → `Scanning` → `TransactionOpen` → `TransactionFinalizing` → `Reconciling` → `Matched|Discrepancy` | `checkout-verification/internal/fsm/` |
| RIP-4-052 | Vision sequence builder: time-ordered `[Item_X to belt, Item_Y to belt, Item_X to bag, ...]` | `checkout-verification/internal/vision/sequence.go` |
| RIP-4-053 | POS sequence builder: consume `retail.pos.transaction-event`; handle `ItemVoided` dynamic removal | `checkout-verification/internal/pos/sequence.go` |
| RIP-4-054 | Modified DTW: align sequences with ±5s matching window per element | `checkout-verification/internal/dtw/matcher.go` |
| RIP-4-055 | DTW cost function: exact SKU match = 0; shelf-region fuzzy match = 0.3; mismatch = 1.0 | `checkout-verification/internal/dtw/cost.go` |
| RIP-4-056 | Void handling: on `ItemVoided`, remove DTW alignment link; re-evaluate | `checkout-verification/internal/dtw/void.go` |
| RIP-4-057 | Multi-pack expansion: query PIM DB; 1 POS `6-Pack` ↔ 6 vision items | `checkout-verification/internal/pim/multipack.go` |
| RIP-4-058 | Manual keyed SKU buffer: hold unmatched vision items up to 15s pending slow POS entry | `checkout-verification/internal/buffer/pending.go` |
| RIP-4-059 | Self-checkout pass-back: item in bagging area originated outside Scanning Zone 3D bbox → `SuspectedPassBack` | `checkout-verification/internal/fraud/passback.go` |
| RIP-4-060 | Settle delay: wait 10s after `TRANSACTION_COMPLETE` before final reconciliation | `checkout-verification/internal/settle/delay.go` |
| RIP-4-061 | Output `TransactionAuditReport{MATCH|MINOR_DISCREPANCY|MAJOR_DISCREPANCY}` to Kafka + ClickHouse | `checkout-verification/internal/report/emitter.go` |
| RIP-4-062 | `Major Discrepancy` routes to LP engine as high-priority evidence | `checkout-verification/internal/lp/routing.go` |

### 4.6 POS Integration
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-4-070 | `services/edge/pos-agent`: webhook adapter (Square, NCR) + ESC/POS serial dongle parser | `services/edge/pos-agent/` |
| RIP-4-071 | Normalize to `retail.pos.TransactionEvent` Protobuf; publish via edge-bridge | `pos-agent/internal/normalize/` |
| RIP-4-072 | Emit `POSHeartbeat` every 10s from pos-agent | `pos-agent/internal/heartbeat/` |
| RIP-4-073 | Cloud consumer validates schema; idempotent insert to ClickHouse `pos_events` | `apps/checkout-verification/internal/pos/consumer.go` |

### 4.7 Outbox Consumers & Snapshot Infrastructure
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-4-080 | Hourly ClickHouse session snapshots for long-term rehydration beyond Redis TTL | `infra/clickhouse/schemas/session_snapshots.sql` |
| RIP-4-081 | Session Reconstruction pod death test: rehydrate from Redis snapshot + Kafka offset | `session-reconstruction/test/rehydrate_test.go` |
| RIP-4-082 | Shared consumer library integration: retry-1/2/3 + DLQ for all Phase 4 consumers | All `apps/*` consumers |

---

## Infrastructure/DevOps Tasks (Phase 4)

| Asset | Detail |
|-------|--------|
| `session-reconstruction` | 12 replicas, consumer lag alert > 1000, Redis Cluster connection pool |
| `reid-service` | GPU optional (CPU inference for embedding compare only); Qdrant client mTLS |
| `lp-engine` | Go + Python sidecar pod (shared IPC via Unix socket); 6 replicas |
| `checkout-verification` | Partition by `session_id`; 6 replicas |
| `evidence-assembler` | Burst CPU node pool; FFmpeg multi-stage container |
| `lp-math` | Python service with `numpy`, `hmmlearn`, `scikit-fuzzy` |
| PIM integration | PostgreSQL `retail.product_catalog` with `multipack_quantity` column |
| Kafka topics | `lp.engine.investigation-task-created`, `retail.checkout.audit-report` |

---

## Production-Ready Implementation Details (Phase 4)

### Session Rehydration (Exact Flow)
1. Service needs state for `session_id=X`.
2. Read Redis `session:X:snapshot` → `{state_blob, snapshot_ts}`.
3. If missing: replay all events from ClickHouse `vision_events` WHERE `session_id=X` (cold start).
4. If present: apply `state_blob` as baseline.
5. Query Kafka/Redis Stream for events WHERE `session_id=X` AND `occurred_at > snapshot_ts`.
6. Fold events in order: `ProductPickedUp` adds to cart; `ProductReturned` removes; `SessionMoved` updates position.
7. Write updated state to Redis HASH; schedule next snapshot if Δt > 5s.
8. Total rehydration target: < 50ms for sessions with < 500 events since snapshot.

### DTW Checkout Alignment (Exact Steps)
1. On `Reconciling` state trigger (POS `PAYMENT_COMPLETED` + 10s settle):
2. Extract Vision sequence `V = [v₁, v₂, ..., vₙ]` — each `vᵢ` = `{sku_or_region, timestamp, scanning_zone_entered}`.
3. Extract POS sequence `P = [p₁, p₂, ..., pₘ]` — each `pᵢ` = `{sku, timestamp, voided_flag}`.
4. Build DTW matrix `D[i][j]` with window constraint `|i/M - j/N| ≤ 0.2` (Sakoe-Chiba band).
5. `D[i][j] = cost(vᵢ, pⱼ) + min(D[i-1][j], D[i][j-1], D[i-1][j-1])`.
6. `cost` = 0 if exact SKU; 0.3 if same `product_category`; 1.0 if unrelated.
7. Backtrace optimal path; unmatched V → `Unscanned Items`; unmatched P → `Ghost Scans`.
8. Query PIM for multi-pack: if `pⱼ.multipack_quantity = k`, match to k consecutive vision items same category.
9. Emit `TransactionAuditReport` with item-level confidence scores.

### LP HMM + Fuzzy Logic Evaluation
1. Hidden state prior from Redis `theft_score` (default 0.01 on session start).
2. On each evidence event `Eₖ`:
   - HMM forward step: `P(Sₜ|E₁:ₜ) ∝ P(Eₜ|Sₜ) × Σₛ P(Sₜ|s)P(s|E₁:ₜ₋₁)`.
   - Fuzzy inputs: `occlusion_duration`, `in_blind_spot`, `concealment_confidence`, `pos_sync_status`.
   - Fuzzy rules: IF `occlusion IS Suspicious` AND `in_blind_spot IS High` THEN `suspicion IS Elevated`.
   - Defuzzify (centroid method) → fuzzy_score.
3. Combined: `final = 0.6 × hmm_posterior + 0.4 × fuzzy_score`.
4. Apply blind-spot penalty from twin: `final × (1 - penalty)`.
5. If POS item scanned for SKU → terminate theft hypothesis for that SKU (reset to 0).
6. Persist `theft_score` to Redis; emit `TheftScoreUpdated` if Δ > 0.05.

### ReID Bayesian Fusion
1. Visual score `Sᵥ = cosine_similarity(query, candidate)` normalized [0,1].
2. Temporal score `Sₜ = 1 - |Δt_actual - Δt_expected| / Δt_expected` clamped [0,1].
3. Trajectory score `Sᵣ = dot(exit_vector, entrance_vector) × distance_penalty`.
4. Prior `P_merge = 0.3` (base rate of same person reappearing).
5. Posterior `P = (Sᵥ × 0.5 + Sₜ × 0.3 + Sᵣ × 0.2) × P_merge / normalization`.
6. Merge if `P > 0.85` (per-store calibrated).

---

## Testing & Validation (Phase 4)

| Test | Procedure | Pass Criteria |
|------|-----------|---------------|
| Session rehydration | Kill reconstruction pod mid-session | New pod recovers state; cart contents identical |
| ReID merge | Person exits Cam A, enters Cam B within travel window | Same `session_id`; posterior > 0.85 logged |
| ReID reject | Different person same clothing within window | New `session_id`; posterior < 0.5 |
| LP concealment | Inject event sequence: pick → blind spot → emerge without product | `SuspicionScore` > 0.85; `InvestigationTask` created |
| LP false positive cancel | Pick → blind spot → scan at POS | Score collapses < 0.1 after scan event |
| POS degraded mode | Stop `POSHeartbeat` 60s | Checkout-skipped logic suspended; P1 alert fired |
| DTW exact match | Vision [A,B] POS [A,B] | `MATCH` report |
| DTW pass-back | Vision [Steak] POS [Banana] | `MAJOR_DISCREPANCY`; LP alert routed |
| DTW void | Scan A, void A, scan A again | Correct re-alignment; no false discrepancy |
| DTW multi-pack | 1 POS 6-pack, 6 vision singles | Mapped; `MATCH` |
| DTW settle delay | Pay then add item to cart within 8s | Item flagged unscanned after settle |
| Sweethearting inject | Cashier slide-scan pattern events | `SuspectedSweethearting` linked to employee_id |
| Evidence package | Trigger investigation | 15s clips + trajectory + timeline + hash in audit log |
| Idempotency | Replay `PaymentCompleted` 10× | Single audit report emitted |

---

## Exit Criteria (Phase 4)

- [ ] Session Reconstruction operational with 5s snapshots and < 50ms rehydration
- [ ] Cross-camera ReID merging with Bayesian fusion; Qdrant TTL purging active
- [ ] LP engine HMM + Fuzzy DAG scoring with POS degraded mode
- [ ] Sweethearting, basket-switch, and blind-spot penalty scenarios detected in event injection tests
- [ ] Checkout DTW producing `TransactionAuditReport` with void/multi-pack/pass-back handling
- [ ] POS agent ingesting heartbeat + transaction events from lab simulator
- [ ] Evidence package assembler producing hashed, anonymized multi-camera artifacts
- [ ] Human feedback loop adjusting HMM weights on `FalsePositive` disposition
- [ ] All consumers using retry/DLQ; zero unbounded partition blocking under fault injection
- [ ] End-to-end synthetic shoplifting scenario: `InvestigationTask` in < 3s from trigger event

**Phase 4 outputs are strict dependencies for Phase 5.**

---

---

# Phase 5: Next.js Enterprise Portal & APIs

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
- [ ] GraphQL p99 < 200ms; ClickHouse dashboard queries p95 < 2s

**Phase 5 outputs are strict dependencies for Phase 6.**

---

---

# Phase 6: Security, Observability & Fleet DevOps

## Phase Objective
Harden the platform for enterprise production: crypto-shredding RTBF, WORM evidence storage with chain-of-custody hashing, full OpenTelemetry SLO burn-rate alerting, GPU DCGM fleet dashboards, GitOps ring deployment for 500+ edge stores, air-gapped image distribution, MLOps shadow/canary model rollout, and Chaos Engineering certification. At exit, the platform passes a formal chaos drill, completes a simulated GDPR deletion via crypto-shred, and deploys a CV model update via ring strategy without tracking interruption.

## Sub-systems Involved
- HashiCorp Vault crypto-shredding keys
- S3/MinIO Object Lock (WORM)
- Append-only audit log service
- OpenTelemetry full-stack instrumentation
- Prometheus SLO burn-rate alerts
- Grafana fleet + CI health dashboards
- DCGM edge fleet monitoring
- ArgoCD/Fleet GitOps ring deployment
- AWS IoT / Fleet agent OTA
- Chaos Mesh / Litmus chaos drills
- MLOps shadow + canary + automated rollback
- Sim Engine ("Matrix") in CI
- k6 load testing harness

---

## Granular Tasks

### 6.1 Crypto-Shredding & GDPR RTBF
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-6-001 | Application-layer AEAD encryption for `session_id`, `employee_id` before Kafka/ClickHouse write | `packages/go-common/crypto/envelope.go` |
| RIP-6-002 | Per-tenant data encryption keys (DEK) in Vault `secret/data/rip/<env>/dek/<tenant_id>` | Vault policy + bootstrap |
| RIP-6-003 | Compliance API `POST /api/compliance/rtbf` accepts `session_id` or timestamp range | `apps/compliance-api/` |
| RIP-6-004 | RTBF executor: delete Vault DEK for session → crypto-shred all linked fields | `compliance-api/internal/shred/` |
| RIP-6-005 | Purge Qdrant vectors, Redis state, S3 evidence for session (non-shredded blobs) | `compliance-api/internal/purge/` |
| RIP-6-006 | Generate `ProofOfDeletion` receipt: signed JSON with shred timestamp + key ID destroyed | `compliance-api/internal/receipt/` |
| RIP-6-007 | Biometric Opt-Out Zone `ForgetMe` integration test with compliance audit trail | `compliance-api/test/rtbf_test.go` |

### 6.2 WORM Storage & Chain of Custody
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-6-010 | Enable MinIO Object Lock COMPLIANCE mode on `evidence-pkgs` and `audit-logs` buckets | `infra/terraform/modules/minio-worm/` |
| RIP-6-011 | S3 Object Lock 7-year default retention; legal-hold API pauses deletion per session | `infra/terraform/modules/s3-worm/` |
| RIP-6-012 | `apps/audit-log` service: INSERT-only; consumes `security.audit_logs` | `apps/audit-log/` |
| RIP-6-013 | Audit events: `EVIDENCE_UNBLURRED`, `INVENTORY_ADJUSTED`, `RTBF_EXECUTED`, `MODEL_PROMOTED` | `packages/proto/rip/security/v1/audit.proto` |
| RIP-6-014 | Evidence hash chain: SHA-256(MP4) + SHA-256(timeline JSON) → audit log immutable row | `audit-log/internal/chain/` |
| RIP-6-015 | Verification API `GET /api/evidence/{id}/verify` recalculates hash vs audit log | `apps/api-gateway/graph/evidence_verify.go` |
| RIP-6-016 | QLDB or private ledger option for hash anchoring (enterprise tier) | `infra/terraform/modules/qldb/` (optional) |

### 6.3 OpenTelemetry Full Instrumentation
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-6-020 | OTel SDK completion audit: 100% Go/Python/TS services instrumented | All `apps/`, `services/` |
| RIP-6-021 | Kafka producer/consumer trace propagation verified end-to-end | `packages/go-common/kafkaconsumer/` |
| RIP-6-022 | Custom spans: `lp.evaluate_hypothesis`, `checkout.dtw_align`, `twin.raycast` | respective services |
| RIP-6-023 | Tail sampling in OTel Collector: keep 100% errors, 10% success, 100% latency > 2s | `infra/helm/charts/otel-collector/tail_sampling.yaml` |
| RIP-6-024 | Grafana Tempo ↔ Loki ↔ Prometheus trace-to-log correlation dashboards | `infra/grafana/dashboards/rip-tracing.json` |

### 6.4 SLO Burn-Rate Alerting
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-6-030 | SLO: CV inference p99 < 100ms, 99.9% over 5m window | `infra/prometheus/slos/cv_inference.yaml` |
| RIP-6-031 | SLO: Evidence package generation p99 < 5s | `infra/prometheus/slos/evidence.yaml` |
| RIP-6-032 | SLO: API GraphQL p99 < 200ms | `infra/prometheus/slos/api.yaml` |
| RIP-6-033 | Multi-window burn-rate alerts: 10×/5m → PagerDuty; 2×/6h → Slack | `infra/prometheus/alerts/burn_rate.yaml` |
| RIP-6-034 | Error budget policy doc: freeze feature deploys when budget < 10% | `docs/runbooks/error-budget-policy.md` |

### 6.5 GPU DCGM Fleet Observability
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-6-040 | DCGM Exporter on all edge nodes; fleet-wide Grafana dashboard | `infra/grafana/dashboards/edge-gpu-fleet.json` |
| RIP-6-041 | Alerts: GPU thermal throttle > 5%, VRAM > 90%, inference queue > 500ms | `infra/prometheus/alerts/gpu.yaml` |
| RIP-6-042 | Model drift dashboard: confidence histogram overlay vs golden baseline | `infra/grafana/dashboards/model_drift.json` |
| RIP-6-043 | Feature store monitoring: frame brightness, bbox size distributions per camera | `cv-orchestrator/metrics/feature_log.py` |
| RIP-6-044 | Camera heartbeat fleet view: `camera_heartbeat_seconds` per store tile map | `infra/grafana/dashboards/camera_fleet.json` |

### 6.6 GitOps Edge Fleet Management
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-6-050 | Fleet controller: manage 500+ K3s clusters via GitOps over WireGuard | `infra/argocd/fleet-controller/` |
| RIP-6-051 | `StoreCustomResource` per store: cameras, models, twin version, feature flags | `edge/fleet-crds/` |
| RIP-6-052 | Ring deployment CLI `fleet deploy --ring 1` (5% stores) → ring 2 (10%) → full | `tools/fleet-cli/` |
| RIP-6-053 | Automated rollback `fleet rollback store-123` on post-deploy error rate spike | `tools/fleet-cli/rollback.go` |
| RIP-6-054 | S3 edge image sync daemon: off-peak OCI layer pull to regional bucket | `services/edge/image-sync/` |
| RIP-6-055 | USB air-gap import path: `k3s ctr images import` runbook + encrypted USB workflow | `docs/runbooks/airgap-deploy.md` |
| RIP-6-056 | ArgoCD drift detection: malicious local config overwrite reverted < 5 min | Fleet agent test |

### 6.7 MLOps Shadow, Canary & Rollback
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-6-060 | Shadow deployment: challenger model → `vision.shadow.tracking` topic only | `cv-orchestrator/mlops/shadow.py` |
| RIP-6-061 | Background evaluator: compare champion vs challenger vs delayed ground truth | `apps/ml-evaluator/` |
| RIP-6-062 | Canary: promote to 2 cameras in 1 store; monitor ID-switch rate + latency 24h | `tools/fleet-cli/canary.yaml` |
| RIP-6-063 | Automated rollback if ID-switch rate increases > 5% or p99 latency > 200ms | `ml-evaluator/internal/rollback/trigger.go` |
| RIP-6-064 | MLflow promotion workflow: Staging → Canary → Production gates | `ml/mlflow/promotion-policy.yaml` |
| RIP-6-065 | Data drift detector: KL divergence on weekly embedding samples vs training set | `apps/ml-evaluator/internal/drift/kl_div.py` |

### 6.8 Chaos Engineering Certification
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-6-070 | Deploy Chaos Mesh on staging EKS + K3s lab | `infra/chaos/chaos-mesh/` |
| RIP-6-071 | Scenario: edge↔cloud network partition 60s | `infra/chaos/scenarios/network_partition.yaml` |
| RIP-6-072 | Scenario: kill Session Reconstruction pod | `infra/chaos/scenarios/pod_kill.yaml` |
| RIP-6-073 | Scenario: GPU OOM on edge via memory stress | `infra/chaos/scenarios/gpu_oom.yaml` |
| RIP-6-074 | Scenario: poison pill malformed Protobuf → DLQ route | `infra/chaos/scenarios/poison_pill.yaml` |
| RIP-6-075 | Scenario: 5s NTP clock skew on POS simulator | `infra/chaos/scenarios/clock_skew.yaml` |
| RIP-6-076 | Measure TTD (time-to-detection) and TTM (time-to-mitigation) per scenario | `infra/chaos/reports/template.md` |
| RIP-6-077 | Quarterly chaos drill calendar + pass/fail certification gate before prod releases | `docs/runbooks/chaos-certification.md` |

### 6.9 Load Testing & CI Observability
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-6-080 | k6 script: 50,000 events/sec × 4 hours Kafka load | `infra/load/k6/kafka_flood.js` |
| RIP-6-081 | k6 script: 500 concurrent portal users opening camera wall | `infra/load/k6/camera_wall.js` |
| RIP-6-082 | Custom Go Kafka producer for sustained throughput baseline | `tools/loadgen/` |
| RIP-6-083 | CI metrics Prometheus: golden dataset F1, inference p99, event-match accuracy | `infra/prometheus/ci/` |
| RIP-6-084 | Grafana CI health dashboard for regression trend detection | `infra/grafana/dashboards/ci_health.json` |

### 6.10 Sim Engine ("Matrix") CI Integration
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-6-090 | `services/sim/matrix-engine`: Unity/Blender headless render + DSL scenario runner | `services/sim/matrix-engine/` |
| RIP-6-091 | DSL parser: `SPAWN`, `MOVE`, `INTERACT`, `OCCLUDE` commands | `matrix-engine/dsl/parser.py` |
| RIP-6-092 | Output RTSP stream from synthetic render → edge ingestor in CI | `.github/workflows/sim-matrix.yml` |
| RIP-6-093 | 5-min synthetic theft scenario per CV/LP PR; F1 gate | CI workflow |
| RIP-6-094 | Domain randomization: lighting, noise, texture variation seeds | `matrix-engine/randomize/` |

### 6.11 Security Hardening Final Pass
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-6-100 | Istio STRICT mTLS audit: no PERMISSIVE modes in prod | Security scan |
| RIP-6-101 | K8s NetworkPolicy audit: CV ✗ PostgreSQL enforced fleet-wide | `infra/helm/charts/network-policies/` |
| RIP-6-102 | Vault secret rotation drill: 30-day RTSP credential rotation | `docs/runbooks/vault-rotation.md` |
| RIP-6-103 | Penetration test remediation tracker for edge outbound-only architecture | `docs/security/pentest/` |
| RIP-6-104 | BIPA bias calibration report: fuzzy logic thresholds per demographic cohort | `lp-math/calibration/bias_report.py` |

---

## Infrastructure/DevOps Tasks (Phase 6)

| Asset | Detail |
|-------|--------|
| MinIO/S3 WORM | COMPLIANCE mode, 7-year retention, legal-hold object tags |
| Vault DEK management | Per-tenant, per-session key hierarchy; destroy = shred |
| Fleet controller | Rancher Fleet or ArgoCD ApplicationSet per store cluster |
| Chaos Mesh | Staging + quarterly prod-shadow drills |
| PagerDuty | P1 routes: edge offline, Kafka partition loss, GPU thermal critical |
| TURN server | coturn for WebRTC NAT traversal on edge |
| ML evaluator | CronJob + Kafka consumer for shadow metrics |
| Load test env | Dedicated MSK cluster matching prod partition topology |

---

## Production-Ready Implementation Details (Phase 6)

### Crypto-Shredding RTBF Execution
1. Admin submits RTBF for `session_id=S` via compliance API (OPA: `ComplianceOfficer` role).
2. Lookup Vault path `secret/data/rip/prod/dek/session/S` → DEK bytes.
3. Delete DEK from Vault; append `RTBF_EXECUTED` to immutable audit log.
4. All ClickHouse rows with encrypted `session_id` for DEK S are now permanently unlinkable (ciphertext remains, key gone).
5. Purge non-encrypted artifacts: S3 evidence blobs, Qdrant vectors, Redis keys matching `*:S`.
6. Issue `ProofOfDeletion` JWT-signed receipt with `{session_id_hash, shredded_at, key_id, auditor_id}`.
7. Aggregate foot-traffic metrics remain accurate (counts preserved, identity destroyed).

### Ring Deployment with Shadow Validation
1. New CV image `v1.3` pushed to ECR; MLflow registers artifact.
2. **Shadow phase (week 1):** Deploy to 3 lab stores; challenger → `vision.shadow.tracking`; evaluator compares F1.
3. **Ring 1 (week 2):** `fleet deploy --ring 1` → 5% low-traffic stores; champion still primary; monitor 24h.
4. **Ring 2 (week 3):** 10% → 50% if ID-switch delta < 3% and p99 < 110ms.
5. **Full (week 4):** 100% fleet; old image retained for `fleet rollback`.
6. Auto-rollback trigger: Grafana alert `id_switch_rate_increase > 5%` → `fleet rollback --ring current`.

### Chaos Drill: Edge↔Cloud Network Partition
1. Chaos Mesh `NetworkChaos`: drop 100% packets edge → MSK for 60s.
2. **Expected TTD < 15s:** `edge_buffer_depth` alert fires.
3. CV pipeline continues; semantic events buffer in Redis Streams.
4. **Expected TTM < 120s after restore:** edge-bridge drains backlog; consumer lag returns to < 50ms within 5 min.
5. ClickHouse row count for test window matches expected (no loss); idempotency keys prevent duplicates.
6. LP engine: no false `CheckoutSkipped` if POS heartbeat still local.

### SLO Burn-Rate Multi-Window Alert
1. SLI: `cv_inference_latency_ms` histogram bucket le 100.
2. Error budget: 0.1% over 30d window.
3. Fast burn: if budget consumed at 10× rate in 5m → P1 PagerDuty.
4. Slow burn: 2× over 6h → P2 Slack.
5. Budget < 10% remaining → freeze deploys per error-budget policy.

---

## Testing & Validation (Phase 6)

| Test | Procedure | Pass Criteria |
|------|-----------|---------------|
| Crypto-shred | Execute RTBF on test session | Encrypted fields irrecoverable; plaintext artifacts purged; receipt issued |
| WORM tamper | Attempt DELETE on locked evidence object | Operation denied; audit log intact |
| Hash verify | Modify 1 byte of evidence MP4 | `verify` API returns `TAMPERED` |
| Burn-rate alert | Inject latency spike 10× for 5m | P1 fires; runbook followed |
| Fleet ring deploy | Deploy CV v1.3 ring 1 (5%) | Zero tracking interruption; rollback in < 2 min |
| Shadow model | Run challenger 24h | Evaluator report generated; auto-reject if F1 drop > 5% |
| Network partition chaos | 60s edge isolation | Zero event loss; no duplicates; TTD < 15s |
| GPU OOM chaos | Exhaust VRAM | DegradedMode; IoU tracking continues; auto-recover < 5 min |
| Poison pill | Malformed Protobuf to topic | DLQ route; consumer continues; alert fires |
| Clock skew | POS +5s NTP skew | DTW tolerates; flags `Unverifiable` not `MAJOR_DISCREPANCY` storm |
| k6 sustained load | 50k events/sec × 4h | Consumer lag < 50ms; ClickHouse insert stable |
| Matrix CI | 5-min synthetic theft PR gate | F1 ≥ 0.92; pipeline blocks on regression |
| DCGM fleet | 10 edge nodes dashboard | All nodes reporting; thermal alert test on injected threshold |

---

## Exit Criteria (Phase 6) — PROGRAM SIGN-OFF

- [ ] Crypto-shredding RTBF operational with `ProofOfDeletion` receipts
- [ ] WORM Object Lock on evidence + audit buckets; hash chain verification API live
- [ ] 100% service OTel instrumentation; tail sampling configured
- [ ] SLO burn-rate alerts paging correctly in staging drill
- [ ] GPU DCGM fleet dashboard covering all edge nodes
- [ ] Fleet GitOps ring deployment completed for one production CV release
- [ ] Shadow → canary → full MLOps pipeline with automated rollback tested
- [ ] All 6 chaos scenarios passed with documented TTD/TTM
- [ ] k6 sustained load test passed (50k events/sec × 4h)
- [ ] Matrix Sim Engine integrated in CI with theft scenario F1 gate
- [ ] Error budget policy enforced (deploy freeze tested)
- [ ] Security audit: STRICT mTLS, NetworkPolicies, Vault rotation drill complete
- [ ] BIPA bias calibration report approved by compliance lead
- [ ] Full runbook catalog reviewed by SRE council

---

**END OF EXECUTION PLAN — All Phases 0–6 Complete.**

