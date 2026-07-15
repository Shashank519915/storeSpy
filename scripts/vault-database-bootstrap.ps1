# Vault Database Secrets Engine bootstrap - run after RDS is live (Phase 1 section 4)
# Requires: vault-0 Running, root token (or admin token with mount permissions)

param(
  [string]$RootToken = "",
  [string]$SecretId = "rip-dev/rds/postgres",
  [string]$DatabasePath = "database"
)

$ErrorActionPreference = "Continue"
$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

function Require-Command($name) {
  if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
    throw "Missing required command: $name"
  }
}

Require-Command aws
Require-Command kubectl

Write-Host "==> Waiting for vault-0"
kubectl wait --for=condition=ready pod/vault-0 -n rip-system --timeout=300s | Out-Null

if (-not $RootToken) {
  if (Test-Path vault-init.json) {
    $RootToken = (Get-Content vault-init.json -Raw | ConvertFrom-Json).root_token
  } else {
    $RootToken = Read-Host "Vault root token"
  }
}

$secretJson = aws secretsmanager get-secret-value --secret-id $SecretId --query SecretString --output text
if (-not $secretJson) { throw "Secret $SecretId not found - apply RDS Terraform first." }
$db = $secretJson | ConvertFrom-Json

$envVars = "VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=$RootToken"

function VaultExec([string]$cmd, [switch]$AllowFailure) {
  $output = kubectl exec -n rip-system vault-0 -- sh -c "$envVars $cmd" 2>&1
  foreach ($line in @($output)) {
    $text = "$line"
    if ($text -match '^WARNING!') {
      Write-Warning $text
    } elseif ($text) {
      Write-Host $text
    }
  }
  if ($LASTEXITCODE -ne 0 -and -not $AllowFailure) {
    throw "Vault command failed (exit $LASTEXITCODE): $cmd"
  }
}

function ShSingleQuote([string]$value) {
  return $value.Replace("'", "'\''")
}

Write-Host "==> Enabling database secrets engine at $DatabasePath"
VaultExec "vault secrets enable -path=$DatabasePath database" -AllowFailure

$connUrl = "postgresql://$($db.username):$($db.password)@$($db.host):$($db.port)/$($db.database)?sslmode=require"
$connUrlEsc = ShSingleQuote $connUrl
VaultExec "vault write $DatabasePath/config/rip-postgresql plugin_name=postgresql-database-plugin allowed_roles=rip-postgresql,rip-postgresql-twin connection_url='$connUrlEsc'"

Write-Host "==> Creating roles"
$dbName = $db.database
$creationFull = @(
  "CREATE ROLE ""{{name}}"" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';"
  "GRANT CONNECT ON DATABASE $dbName TO ""{{name}}"";"
  "GRANT USAGE ON SCHEMA public, identity, retail, twin TO ""{{name}}"";"
  "GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public, identity, retail, twin TO ""{{name}}"";"
  "ALTER DEFAULT PRIVILEGES IN SCHEMA public, identity, retail, twin GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO ""{{name}}"";"
) -join " "
$creationFullEsc = ShSingleQuote $creationFull

VaultExec "vault write $DatabasePath/roles/rip-postgresql db_name=rip-postgresql creation_statements='$creationFullEsc' default_ttl=1h max_ttl=24h"

$creationTwin = @(
  "CREATE ROLE ""{{name}}"" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';"
  "GRANT CONNECT ON DATABASE $dbName TO ""{{name}}"";"
  "GRANT USAGE ON SCHEMA twin TO ""{{name}}"";"
  "GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA twin TO ""{{name}}"";"
  "ALTER DEFAULT PRIVILEGES IN SCHEMA twin GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO ""{{name}}"";"
) -join " "
$creationTwinEsc = ShSingleQuote $creationTwin

VaultExec "vault write $DatabasePath/roles/rip-postgresql-twin db_name=rip-postgresql creation_statements='$creationTwinEsc' default_ttl=1h max_ttl=24h"

Write-Host "==> Installing Vault policies"
kubectl cp infra/vault/policies/rip-twin-api.hcl rip-system/vault-0:/tmp/rip-twin-api.hcl
kubectl cp infra/vault/policies/rip-debezium.hcl rip-system/vault-0:/tmp/rip-debezium.hcl
VaultExec "vault policy write rip-twin-api /tmp/rip-twin-api.hcl"
VaultExec "vault policy write rip-debezium /tmp/rip-debezium.hcl"

Write-Host "==> Binding twin-api Kubernetes auth role"
VaultExec "vault write auth/kubernetes/role/twin-api bound_service_account_names=twin-api bound_service_account_namespaces=rip-system policies=rip-twin-api ttl=1h" -AllowFailure

Write-Host "==> Storing Debezium static creds reference in KV"
VaultExec "vault kv put secret/rip/dev/debezium/postgres host=$($db.host) port=$($db.port) database=$($db.database) username=$($db.username)" -AllowFailure

Write-Host ""
Write-Host "Vault database bootstrap complete."
Write-Host "  Dynamic creds (full):  database/creds/rip-postgresql"
Write-Host "  Dynamic creds (twin):  database/creds/rip-postgresql-twin"
Write-Host "  K8s auth role:         twin-api maps to rip-twin-api policy"
