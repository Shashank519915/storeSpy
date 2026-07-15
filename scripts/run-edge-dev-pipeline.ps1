# Run cloud-only edge CV demo (no GPU / no Kafka)
$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

Write-Host "==> ingestor (virtual, 10 frames)"
Push-Location services/edge/ingestor
go run ./cmd/ingestor -source virtual -max-frames 10 -http :18080
Pop-Location

Write-Host "==> cv-orchestrator FSM"
Push-Location services/edge/cv-orchestrator
python -m orchestrator.main --person --hand-in-shelf
Pop-Location

Write-Host "==> state-publisher"
Push-Location services/edge/state-publisher
go run ./cmd/state-publisher
Pop-Location

Write-Host "==> edge dev pipeline demo complete"
