# RIP Phase 4: Cloud Reasoning & State Engines
**Prerequisites:** Phase 3 exit criteria met
**Governance:** code_style.md, design-tokens.md
**Master plan:** rip-execution-plan.md (this is the standalone working copy)


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

