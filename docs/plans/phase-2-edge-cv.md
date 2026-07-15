# RIP Phase 2: Edge CV Pipeline Core
**Prerequisites:** Phase 1 exit criteria met
**Governance:** code_style.md, design-tokens.md
**Master plan:** rip-execution-plan.md (this is the standalone working copy)

## Deferred from Phase 0 (Step E — edge lab)

Phase 0 runbook Step E (K3s lab, GPU Operator, SPIRE edge SVIDs, WireGuard soak) is **optional for Phase 0 exit** and is a **hard prerequisite for Phase 2 exit**. Complete before starting Phase 2 edge CV work:

| Phase 0 ticket | Phase 2 dependency | Runbook |
|----------------|-------------------|---------|
| RIP-0-040–046 Ansible + K3s + GPU + SPIRE + WireGuard | Strimzi edge Kafka (RIP-1-020), Triton on K3s (RIP-2-020), ingestor NVDEC tests | `docs/runbooks/phase-0-live-deployment.md` §Step E |
| RIP-0-044 SPIRE edge SVIDs | MinIO mTLS edge auth (RIP-1-093), Fleet GitOps | `infra/ansible/`, `infra/helm/charts/spire/` |

Cloud-only Phase 1 work (MSK, RDS, ClickHouse) can proceed in parallel while edge hardware is provisioned.

**No hardware?** Use the cloud dev path: `docs/runbooks/phase-2-cloud-dev.md` (Virtual Camera, local FSM/homography, NDJSON events). GPU/K3s items remain deferred until hardware is available.


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

### Progress (Phase 2 cloud dev — no hardware)

- [x] RIP-2-001 — Go ingestor scaffold (`services/edge/ingestor`)
- [x] RIP-2-004/005 — Software ring buffer + drop-oldest policy
- [x] RIP-2-008 — `InputSource` interface (`virtual`, `file` adapters)
- [x] RIP-2-010 — Health/metrics (`/healthz`, `cv_dropped_frames_total`)
- [x] RIP-2-030 — Perception FSM (`cv-orchestrator/orchestrator/sampling/fsm.py`)
- [x] RIP-2-050..055 — Homography DLT + stub calibration loader
- [x] RIP-2-080 — State publisher NDJSON envelope (`state-publisher`)
- [x] RIP-2-090 — Virtual Camera driver (synthetic frames)
- [x] RIP-2-091 — Golden dataset manifests (`ml/golden-datasets/manifests/`)
- [x] **Cloud dev runbook** — `docs/runbooks/phase-2-cloud-dev.md`
- [ ] RIP-2-002/003 — RTSP pool + reconnect (needs RTSP server)
- [ ] RIP-2-020+ — Triton on K3s GPU (needs edge hardware)
- [ ] RIP-2-040+ — BoT-SORT live tracking (needs Triton + golden clips)
- [ ] RIP-2-092 — GPU golden CI workflow

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

