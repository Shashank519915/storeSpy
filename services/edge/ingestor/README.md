# ingestor

Go ingest service for edge frame capture. **Cloud dev path** uses Virtual Camera and file replay without CUDA/NVDEC.

## Run (no hardware)

```powershell
cd services/edge/ingestor
go test ./...
go run ./cmd/ingestor -source virtual -camera-id cam-virtual-01 -fps 10 -max-frames 30
```

## Sources

| `-source` | Description |
|-----------|-------------|
| `virtual` | Synthetic RGB frames (default) |
| `file` | JPEG/PNG file or directory replay |

## Tickets

- RIP-2-001 scaffold (cloud dev)
- RIP-2-004/005 ring buffer with drop-oldest
- RIP-2-008 `InputSource` interface
- RIP-2-010 health + `cv_dropped_frames_total` metric

GPU/NVDEC path (K3s lab): see `docs/runbooks/phase-2-cloud-dev.md`.
