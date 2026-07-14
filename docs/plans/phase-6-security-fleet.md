# RIP Phase 6: Security, Observability & Fleet DevOps
**Prerequisites:** Phase 5 exit criteria met
**Governance:** code_style.md, design-tokens.md
**Master plan:** rip-execution-plan.md (this is the standalone working copy)


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
