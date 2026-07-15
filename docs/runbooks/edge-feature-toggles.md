## Edge runtime toggles (`infra/config/dev/edge-flags.yaml`)

Used by `scripts/run-edge-pipeline.ps1`. All hardware paths default **off** until you provision edge lab (much later).

| Flag | Default | When to enable |
|------|---------|----------------|
| `enable_edge_hardware` | `false` | K3s GPU lab + WireGuard edge node available |
| `enable_rtsp_ingest` | `false` | Real RTSP cameras on edge network |
| `enable_gpu_nvdec` | `false` | NVIDIA GPU with NVDEC on edge node |
| `enable_triton_inference` | `false` | Triton deployed on K3s with TensorRT engines |
| `enable_redis_publish` | `false` | Edge Redis Streams available |
| `enable_kafka_publish` | `false` | MSK or in-cluster Kafka (`enable_msk` / `enable_incluster_kafka`) |
| `enable_rds_outbox_sink` | `true` | Write `ProductPickedUp` to RDS outbox (Phase 1 Path A) |

**Cloud dev (now):** all hardware/kafka flags `false`, `enable_rds_outbox_sink=true`.

```powershell
# Full wired pipeline -> RDS outbox (port-forwards PgBouncer automatically)
.\scripts\run-edge-pipeline.ps1

# Local stdout only (no AWS/kubectl)
.\scripts\run-edge-pipeline.ps1 -StdoutOnly
```
