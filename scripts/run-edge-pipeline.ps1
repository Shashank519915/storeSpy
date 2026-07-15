# Wired edge pipeline: ingestor -> orchestrator -> state-publisher (toggle-aware)
param(
  [switch]$SkipOutbox,
  [switch]$StdoutOnly
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("Path", "User")
$goBin = "C:\Program Files\Go\bin"
if (Test-Path $goBin) { $env:Path = "$goBin;" + $env:Path }
if (-not (Get-Command go -ErrorAction SilentlyContinue)) {
  throw "Go not found. Run: winget install GoLang.Go"
}

function Require-Command($name) {
  if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
    throw "Missing required command: $name"
  }
}

function Read-EdgeFlags {
  $path = Join-Path $RepoRoot "infra/config/dev/edge-flags.yaml"
  $flags = @{}
  Get-Content $path | ForEach-Object {
    if ($_ -match '^\s*([a-z_]+):\s*(true|false)\s*') {
      $flags[$Matches[1]] = [bool]::Parse($Matches[2])
    } elseif ($_ -match '^\s*([a-z_]+):\s*(\d+)\s*') {
      $flags[$Matches[1]] = [int]$Matches[2]
    } elseif ($_ -match '^\s*([a-z_]+):\s*([^\s#]+)') {
      $flags[$Matches[1]] = $Matches[2]
    }
  }
  return $flags
}

$flags = Read-EdgeFlags
$frames = if ($flags.pipeline_frames) { $flags.pipeline_frames } else { 30 }
$fps = if ($flags.pipeline_fps) { $flags.pipeline_fps } else { 10 }
$camera = if ($flags.virtual_camera_id) { $flags.virtual_camera_id } else { "cam-virtual-01" }

if ($flags.enable_edge_hardware) {
  Write-Warning "enable_edge_hardware=true - lab not provisioned; using virtual camera"
}
if ($flags.enable_rtsp_ingest -or $flags.enable_gpu_nvdec) {
  Write-Warning "RTSP/GPU toggles on - virtual camera used until hardware exists"
}

$sink = "stdout"
$databaseURL = ""
$pfJob = $null

$useOutbox = $flags.enable_rds_outbox_sink -and -not $SkipOutbox -and -not $StdoutOnly
if ($useOutbox) {
  Require-Command aws
  Require-Command kubectl
  $sink = "outbox"
  Write-Host "==> Port-forward PgBouncer (localhost:15432)"
  $pfJob = Start-Job -ScriptBlock {
    kubectl port-forward svc/pgbouncer -n rip-system 15432:5432 2>&1 | Out-Null
  }
  Start-Sleep -Seconds 3
  $secret = aws secretsmanager get-secret-value --secret-id rip-dev/rds/postgres --query SecretString --output text | ConvertFrom-Json
  $databaseURL = "postgresql://$($secret.username):$($secret.password)@localhost:15432/$($secret.database)?sslmode=disable"
  $env:DATABASE_URL = $databaseURL
}

$tmp = Join-Path $env:TEMP "rip-edge-pipeline"
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$framesFile = Join-Path $tmp "frames.ndjson"
$eventsFile = Join-Path $tmp "events.ndjson"

Write-Host "==> Wired pipeline (frames=$frames fps=$fps sink=$sink)"

Push-Location services/edge/ingestor
$ingestorErr = Join-Path $tmp "ingestor.err"
$prevEAP = $ErrorActionPreference
$ErrorActionPreference = "Continue"
go run ./cmd/pipeline -camera-id $camera -fps $fps -max-frames $frames 2> $ingestorErr |
  Where-Object { $_.Trim().StartsWith("{") } |
  Set-Content -Encoding utf8 $framesFile
$ErrorActionPreference = $prevEAP
if (Test-Path $ingestorErr) { Get-Content $ingestorErr | ForEach-Object { Write-Host $_ } }
Pop-Location

Push-Location services/edge/cv-orchestrator
Get-Content $framesFile | Where-Object { $_.Trim().StartsWith("{") } | python -m orchestrator.pipeline.runner 2>&1 | Tee-Object -Variable orchLog | Set-Content -Encoding utf8 $eventsFile
$orchLog | Where-Object { $_ -notmatch '^\{' } | ForEach-Object { Write-Host $_ }
Pop-Location

$eventLines = Get-Content $eventsFile -ErrorAction SilentlyContinue | Where-Object { $_.Trim().StartsWith("{") }
if (-not $eventLines -or $eventLines.Count -eq 0) {
  Write-Warning "No events from orchestrator"
} else {
  Push-Location services/edge/state-publisher
  $prevEAP = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  if ($sink -eq "outbox") {
    $eventLines | go run ./cmd/state-publisher -stdin -sink outbox "-database-url=$databaseURL"
  } else {
    $eventLines | go run ./cmd/state-publisher -stdin -sink stdout
  }
  $ErrorActionPreference = $prevEAP
  Pop-Location
}

if ($pfJob) {
  Stop-Job $pfJob -ErrorAction SilentlyContinue
  Remove-Job $pfJob -Force -ErrorAction SilentlyContinue
}

Write-Host "==> Wired edge pipeline complete (sink=$sink)"
