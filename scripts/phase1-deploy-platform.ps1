# Phase 1 platform deploy — RDS path + optional Kafka stack (toggle-gated)
# Run from repo root after Phase 0 platform is healthy.
#
# Toggles: infra/config/dev/feature-flags.yaml
# Terraform toggles: infra/terraform/environments/dev/feature-toggles.tf

param(
  [string]$RdsEndpoint = "",
  [string]$KafkaBootstrap = "",
  [switch]$SkipMigrations,
  [switch]$SkipVaultDatabase,
  [switch]$ForceKafkaDev
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

function Require-Command($name) {
  if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
    throw "Missing required command: $name"
  }
}

function Read-FeatureFlags {
  $path = Join-Path $RepoRoot "infra/config/dev/feature-flags.yaml"
  if (-not (Test-Path $path)) { throw "Missing $path" }
  $flags = @{}
  Get-Content $path | ForEach-Object {
    if ($_ -match '^\s*([a-z_]+):\s*(true|false)\s*$') {
      $flags[$Matches[1]] = [bool]::Parse($Matches[2])
    }
  }
  return $flags
}

Require-Command aws
Require-Command kubectl
Require-Command helm

$flags = Read-FeatureFlags
Write-Host "==> Feature flags: $($flags | ConvertTo-Json -Compress)"

Write-Host "==> Refreshing kubeconfig for rip-dev"
aws eks update-kubeconfig --region us-east-1 --name rip-dev | Out-Null

helm repo add bitnami https://charts.bitnami.com/bitnami 2>$null
helm repo add confluentinc https://packages.confluent.io/helm 2>$null
helm repo add icoretech https://icoretech.github.io/helm 2>$null
helm repo update

if (-not $RdsEndpoint) {
  # Use --db-instance-identifier (avoid JMESPath [?...] which breaks PowerShell parsing)
  $RdsEndpoint = aws rds describe-db-instances `
    --db-instance-identifier rip-dev-postgres `
    --query 'Endpoint.Address' `
    --output text 2>$null
  if (-not $RdsEndpoint -or $RdsEndpoint -eq "None") {
    if ($flags.enable_rds) {
      Write-Warning "RDS rip-dev-postgres not found. Apply Terraform with enable_rds=true first."
    }
    $RdsEndpoint = ""
  }
}

# Kafka bootstrap resolution (MSK > explicit param > in-cluster)
if (-not $KafkaBootstrap) {
  if ($flags.enable_msk) {
    Write-Warning "enable_msk=true: fetch bootstrap from TFC output msk_bootstrap_brokers_sasl_iam and pass -KafkaBootstrap"
  } elseif ($flags.enable_incluster_kafka -or $ForceKafkaDev) {
    $KafkaBootstrap = "kafka-dev.rip-system.svc.cluster.local:9092"
  }
}

if ($flags.enable_incluster_kafka -or $ForceKafkaDev) {
  Write-Host "==> Deploying in-cluster Kafka (kafka-dev)"
  helm upgrade --install kafka-dev bitnami/kafka -n rip-system `
    -f infra/helm/charts/kafka-dev/values-dev.yaml `
    --create-namespace --wait --timeout 15m
  if (-not $KafkaBootstrap) {
    $KafkaBootstrap = "kafka-dev.rip-system.svc.cluster.local:9092"
  }
} else {
  Write-Host "==> Skipping in-cluster Kafka (enable_incluster_kafka=false)"
}

if ($RdsEndpoint) {
  Write-Host "==> Deploying PgBouncer -> $RdsEndpoint"
  $secretJson = aws secretsmanager get-secret-value --secret-id rip-dev/rds/postgres --query SecretString --output text 2>$null
  $pgPassword = ""
  if ($secretJson) {
    $pgPassword = ($secretJson | ConvertFrom-Json).password
  }
  $pgArgs = @(
    "upgrade", "--install", "pgbouncer", "icoretech/pgbouncer",
    "-n", "rip-system",
    "-f", "infra/helm/charts/pgbouncer/values.yaml",
    "-f", "infra/helm/charts/pgbouncer/values-dev.yaml",
    "--set", "config.databases.rip.host=$RdsEndpoint",
    "--wait", "--timeout", "10m"
  )
  if ($pgPassword) {
    $pgArgs += @("--set", "config.adminPassword=$pgPassword", "--set", "config.users.rip_admin.password=$pgPassword")
  } else {
    Write-Warning "Secret rip-dev/rds/postgres not found - set PgBouncer password manually or re-apply RDS Terraform."
  }
  helm @pgArgs

  if (-not $SkipMigrations) {
    & (Join-Path $PSScriptRoot "run-rds-migrations.ps1") -RdsEndpoint $RdsEndpoint
  }
} else {
  Write-Host "==> Skipping PgBouncer / migrations (no RDS endpoint)"
}

if ($KafkaBootstrap -and $flags.enable_schema_registry) {
  Write-Host "==> Deploying Schema Registry"
  helm upgrade --install schema-registry confluentinc/schema-registry -n rip-system `
    -f infra/helm/charts/schema-registry/values.yaml `
    -f infra/helm/charts/schema-registry/values-dev.yaml `
    --set kafka.bootstrapServers=$KafkaBootstrap `
    --wait --timeout 10m
} else {
  Write-Host "==> Skipping Schema Registry (toggle off or no Kafka bootstrap)"
}

if ($KafkaBootstrap -and $flags.enable_debezium -and $RdsEndpoint) {
  Write-Host "==> Deploying Kafka Connect (Debezium)"
  $manifest = Get-Content infra/k8s/kafka-connect/deployment.yaml -Raw
  $manifest = $manifest -replace 'REPLACE_KAFKA_BOOTSTRAP', $KafkaBootstrap
  $manifest | kubectl apply -f -
  kubectl rollout status deployment/kafka-connect -n rip-system --timeout=300s
  Write-Host "    Connector spec: infra/helm/charts/kafka-connect/debezium-outbox.json"
  Write-Host "    Apply connector:  .\scripts\apply-debezium-connector.ps1"
} else {
  Write-Host "==> Skipping Debezium (requires enable_debezium + Kafka + RDS)"
}

if ($RdsEndpoint -and -not $SkipVaultDatabase) {
  Write-Host "==> Vault database engine (interactive - needs root token if not in vault-init.json)"
  & (Join-Path $PSScriptRoot "vault-database-bootstrap.ps1")
}

Write-Host ""
Write-Host "Phase 1 deploy pass complete."
Write-Host "  RDS:     $RdsEndpoint"
if ($KafkaBootstrap) {
  Write-Host "  Kafka:   $KafkaBootstrap"
} else {
  Write-Host "  Kafka:   none (MSK or enable_incluster_kafka)"
}
Write-Host "  Runbook: docs/runbooks/phase-1-live-deployment.md"
