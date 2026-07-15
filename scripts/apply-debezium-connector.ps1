# Register Debezium outbox connector against kafka-connect REST API
param(
  [string]$ConnectUrl = "http://localhost:8083",
  [string]$SecretId = "rip-dev/rds/postgres",
  [switch]$PortForward
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $RepoRoot

if ($PortForward) {
  Write-Host "Port-forward kafka-connect:8083 in another terminal, then re-run without -PortForward"
  kubectl port-forward -n rip-system svc/kafka-connect 8083:8083
  exit 0
}

$secretJson = aws secretsmanager get-secret-value --secret-id $SecretId --query SecretString --output text
if (-not $secretJson) { throw "Secret $SecretId not found" }
$db = $secretJson | ConvertFrom-Json

$template = Get-Content infra/helm/charts/kafka-connect/debezium-outbox.json -Raw
$body = $template `
  -replace '\$\{DATABASE_HOST\}', $db.host `
  -replace '\$\{DATABASE_USER\}', $db.username `
  -replace '\$\{DATABASE_PASSWORD\}', $db.password

$uri = "$ConnectUrl/connectors"
Write-Host "==> POST $uri"
Invoke-RestMethod -Method Post -Uri $uri -ContentType "application/json" -Body $body
Write-Host "==> Connector registered. Check status:"
Write-Host "    curl $ConnectUrl/connectors/rip-outbox-connector/status"
