# RIP Phase 1: The Event Backbone & Data Layer
**Prerequisites:** Phase 0 exit criteria met (see deferred items below)
**Governance:** code_style.md, design-tokens.md
**Master plan:** rip-execution-plan.md (this is the standalone working copy)

## Deferred from Phase 0 (do not block Phase 1)

| Item | Deferred to | Notes |
|------|-------------|-------|
| Grafana / kube-prometheus-stack | Post–Phase 6 hardening | `rip-dev` uses `t3.small`; monitoring dashboards re-enabled after node upgrade |
| Vault PostgreSQL dynamic secrets (RIP-0-023) | **This phase — §1.5** (RIP-1-047) | Configure after RDS PostgreSQL is live; path `database/creds/rip-postgresql` |
| Phase 0 Step E edge lab (K3s, SPIRE, WireGuard) | **Phase 2** (see `phase-2-edge-cv.md`) | Cloud backbone first; edge lab required before edge CV exit criteria |
| **Amazon MSK** | **After AWS billing subscription** | Set `enable_msk = true` in TFC or `feature-toggles.tf`. See `docs/runbooks/feature-toggles.md`. Until then: RDS + outbox; flip `enable_incluster_kafka` for Debezium dev path. |


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

### Progress (Phase 1 kickoff)

- [x] RIP-1-001 — `EventEnvelope` + `google.protobuf.Any` payload
- [x] RIP-1-002 — `TrackletUpdated`
- [x] RIP-1-003 — `ProductPickedUp`, `ProductReturned`, `ConcealmentDetected`
- [x] RIP-1-004 — `TransactionEvent`
- [x] RIP-1-005 — `LayoutChanged`, `CameraPitchChanged`, `ShelfMoved`
- [x] RIP-1-006 — `HypothesisUpdated`, `InvestigationTaskCreated`
- [x] RIP-1-007 — `schema-registry.yml` CI (buf lint/breaking/generate; push when `BUF_TOKEN` set)
- [x] RIP-1-008 — `buf.gen.yaml` (Go, Python, TypeScript)
- [x] RIP-1-030 — `infra/migrations/001_outbox.sql`
- [x] RIP-1-014 — `docs/runbooks/kafka-serde.md`
- [x] RIP-1-016 — MSK IAM roles (`msk-iam`: admin, producer, consumer) — gated by `enable_msk`
- [ ] RIP-1-010 live — MSK cluster (`enable_msk=true` after AWS MSK subscription)
- [x] RIP-1-011 — Topic manifest `msk-topics` + EKS bootstrap Job
- [x] RIP-1-012 — Partition strategy documented (`kafka-topic-catalog.md`)
- [x] RIP-1-015 — DLQ + retry topics per consumer domain
- [x] RIP-1-013 — Schema Registry Helm values scaffold (deploy when `enable_schema_registry=true`)
- [ ] RIP-1-013 live — deploy Schema Registry after Kafka bootstrap available
- [ ] RIP-1-014 — Wire Serde end-to-end with live registry
- [x] **Feature toggles** — `enable_msk`, `enable_rds`, `enable_incluster_kafka`, `enable_schema_registry`, `enable_debezium` (`docs/runbooks/feature-toggles.md`)
- [x] RIP-1-040 — RDS module (`rds-postgres`, `enable_rds=true` default)
- [x] RIP-1-041 — `002_schemas.sql` (PostGIS + schemas)
- [x] RIP-1-042 — `003_identity.sql`
- [x] RIP-1-043 — `004_retail.sql`
- [x] RIP-1-044 — `005_twin.sql`
- [x] RIP-1-045 — `006_indexes.sql`
- [x] RIP-1-046 — PgBouncer Helm values scaffold
- [x] RIP-1-031 — Kafka Connect / Debezium scaffold (`kafka-connect/`, `debezium-outbox.json`, `infra/k8s/kafka-connect/`)
- [x] RIP-1-033 — `apps/event-injector` (outbox row in TX)
- [x] RIP-1-047 — Vault DB bootstrap script + `twin-api` policy (`scripts/vault-database-bootstrap.ps1`)
- [x] RIP-1-051–055 — ClickHouse schema scaffolds (`infra/clickhouse/schemas/`)
- [x] RIP-1-081–082 — Redis key schema docs (`docs/runbooks/redis-key-schema.md`)
- [x] RIP-1-100 — `packages/go-common/kafkaconsumer` scaffold + unit test
- [x] **Phase 1 Path A live** — RDS, PgBouncer, migrations, Vault DB on rip-dev (`docs/runbooks/phase-1-live-deployment.md` live deployment record)
- [ ] RIP-1-031 live — deploy Connect when `enable_debezium=true` + Kafka
- [x] RIP-1-047 live — Vault DB bootstrap run after RDS ACTIVE (rip-dev 2026-07-15)

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
| RIP-1-047 | Vault dynamic creds for `twin-api` SA → `twin` schema only | Vault policy HCL — **after RDS live** (deferred from Phase 0 RIP-0-023) |

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
- [x] Runbook: `phase-1-live-deployment.md`, `feature-toggles.md`, `redis-key-schema.md`

**Phase 1 outputs are strict dependencies for Phase 2.**

---

