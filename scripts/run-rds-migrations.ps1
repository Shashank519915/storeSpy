# Apply SQL migrations 001–006 against RDS PostgreSQL
# Uses AWS Secrets Manager rip-dev/rds/postgres when -RdsEndpoint omitted.

param(
  [string]$RdsEndpoint = "",
  [string]$Database = "rip",
  [string]$Username = "rip_admin"
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $RepoRoot

function Require-Command($name) {
  if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
    throw "Missing required command: $name (install PostgreSQL client tools)"
  }
}

Require-Command aws
Require-Command psql

$secretJson = aws secretsmanager get-secret-value --secret-id rip-dev/rds/postgres --query SecretString --output text
if (-not $secretJson) { throw "Secret rip-dev/rds/postgres not found — apply RDS Terraform first." }
$secret = $secretJson | ConvertFrom-Json

if (-not $RdsEndpoint) { $RdsEndpoint = $secret.host }
$password = $secret.password
$env:PGPASSWORD = $password

$migrations = @(
  "001_outbox.sql",
  "002_schemas.sql",
  "003_identity.sql",
  "004_retail.sql",
  "005_twin.sql",
  "006_indexes.sql"
)

Write-Host "==> Applying migrations to $RdsEndpoint / $Database"
foreach ($file in $migrations) {
  $path = Join-Path $RepoRoot "infra/migrations/$file"
  if (-not (Test-Path $path)) { throw "Missing migration $path" }
  Write-Host "    -> $file"
  psql -h $RdsEndpoint -U $Username -d $Database -v ON_ERROR_STOP=1 -f $path
}

Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
Write-Host "==> Migrations complete."
