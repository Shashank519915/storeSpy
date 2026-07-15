# Phase 2 Cloud Development (No Edge Hardware)

**Status (rip-dev 2026-07-15):** Phase 2 **cloud dev path complete**. Hardware/GPU/Triton items deferred.

Develop and test the edge CV pipeline **without GPU, K3s, or RTSP cameras**. Uses Virtual Camera + RDS outbox until edge lab hardware exists.

**Plan reference:** `docs/plans/phase-2-edge-cv.md`  
**Phase 1 prerequisite:** Path A complete (`docs/runbooks/phase-1-live-deployment.md`)  
**Next:** Phase 3 (`docs/runbooks/phase-3-live-deployment.md`)

---

## What runs locally (no hardware)

| Component | Path | Purpose |
|-----------|------|---------|
| Ingestor | `services/edge/ingestor` | Virtual Camera / image file replay, ring buffer, health metrics |
| CV orchestrator | `services/edge/cv-orchestrator` | Perception FSM + homography math |
| State publisher | `services/edge/state-publisher` | `ProductPickedUp` to stdout or RDS outbox |
| Golden validator | `orchestrator/golden/validate.py` | Manifest check (CI `cv-golden.yml`) |
| Golden manifests | `ml/golden-datasets/manifests/` | Expected event vectors |

**Deferred until hardware or MSK billing:** Triton TensorRT, NVDEC CUDA, BoT-SORT live tracking, Redis/Kafka publish, edge-bridge.

**Edge toggles:** `infra/config/dev/edge-flags.yaml` — see `docs/runbooks/edge-feature-toggles.md`

---

## Wired pipeline (recommended)

End-to-end without hardware: **Virtual Camera -> FSM -> RDS outbox**

```powershell
# Writes ProductPickedUp to live rip-dev outbox via PgBouncer port-forward
.\scripts\run-edge-pipeline.ps1

# With golden manifest validation
.\scripts\run-edge-pipeline.ps1 -StdoutOnly -ValidateGolden

# Stdout only (no kubectl/AWS)
.\scripts\run-edge-pipeline.ps1 -StdoutOnly
```

Stages:

1. `ingestor/cmd/pipeline` — emits frame ticks (NDJSON)
2. `orchestrator/pipeline/runner` — mock detect + FSM + temporal filter
3. `state-publisher -stdin -sink outbox` — inserts outbox row

Legacy three-step demo (still works):

```powershell
.\scripts\run-edge-dev-pipeline.ps1
```

### 1. Ingestor (Virtual Camera)

```powershell
cd services\edge\ingestor
go run ./cmd/ingestor -source virtual -camera-id cam-virtual-01 -fps 10 -max-frames 30
```

Health/metrics (separate terminal):

```powershell
curl http://localhost:8080/healthz
curl http://localhost:8080/metrics
```

### 2. CV orchestrator FSM tick

```powershell
cd services\edge\cv-orchestrator
pip install -e ".[dev]"
python -m orchestrator.main --person --hand-in-shelf
pytest
```

### 3. State publisher (synthetic pickup event)

```powershell
cd services\edge\state-publisher
go run ./cmd/state-publisher -store-id store-dev-01 -session-id session-dev-01
```

### 4. One-shot local pipeline demo

```powershell
.\scripts\run-edge-dev-pipeline.ps1
```

---

## File / image source (optional)

Place JPEG/PNG frames in a folder and replay:

```powershell
go run ./cmd/ingestor -source file -file C:\path\to\frames -camera-id cam-file-01 -fps 5 -max-frames 20
```

---

## Homography stub

Calibration stub for twin schema (Phase 3 full):

`ml/golden-datasets/manifests/calibration-stub.json`

```python
from orchestrator.spatial.homography import load_calibration_stub, project_bottom_center
h = load_calibration_stub("ml/golden-datasets/manifests/calibration-stub.json")
pt = project_bottom_center(h, (120, 80, 200, 300))
```

---

## When you get edge hardware later

1. Phase 0 Step E: K3s + GPU Operator (`docs/runbooks/phase-0-live-deployment.md` §Step E)
2. Deploy Triton + NVDEC ingestor on GPU node
3. Point state-publisher at Redis Streams / Kafka (when MSK or in-cluster Kafka enabled)
4. Run golden dataset CI (`.github/workflows/cv-golden.yml` — add when GPU runner available)

---

## Credential rotation

`docs/runbooks/credential-rotation.md`
