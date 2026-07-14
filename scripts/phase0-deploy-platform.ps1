# Phase 0 platform deploy — Steps C + D (dev / t3.micro)
# Run from repo root in PowerShell after Step B (kubectl works).

param(
  [string]$VaultIrsaRoleArn = "",
  [switch]$SkipVaultBootstrap
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $RepoRoot

$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

function Require-Command($name) {
  if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
    throw "Missing required command: $name"
  }
}

Require-Command aws
Require-Command kubectl
Require-Command helm

Write-Host "==> Refreshing kubeconfig for rip-dev"
aws eks update-kubeconfig --region us-east-1 --name rip-dev | Out-Null

if (-not $VaultIrsaRoleArn) {
  $VaultIrsaRoleArn = aws iam list-roles --query "Roles[?RoleName=='rip-dev-vault'].Arn" --output text 2>$null
  if (-not $VaultIrsaRoleArn -or $VaultIrsaRoleArn -eq "None") {
    Write-Warning "Vault IRSA role rip-dev-vault not found. Apply Terraform vault-prerequisites first, or pass -VaultIrsaRoleArn."
  }
}

Write-Host "==> Adding Helm repositories"
helm repo add hashicorp https://helm.releases.hashicorp.com 2>$null
helm repo add istio https://istio-release.storage.googleapis.com/charts 2>$null
helm repo add argo https://argoproj.github.io/argo-helm 2>$null
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>$null
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts 2>$null
helm repo add external-secrets https://charts.external-secrets.io 2>$null
helm repo update

Write-Host "==> Creating namespaces"
kubectl create namespace rip-system --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

Write-Host "==> Wave 0 — Vault (dev)"
$vaultArgs = @(
  "upgrade", "--install", "vault", "hashicorp/vault",
  "-n", "rip-system",
  "-f", "infra/helm/charts/vault/values.yaml",
  "-f", "infra/helm/charts/vault/values-dev.yaml",
  "--wait", "--timeout", "10m"
)
if ($VaultIrsaRoleArn) {
  $vaultArgs += @("--set", "server.serviceAccount.annotations.eks\.amazonaws\.com/role-arn=$VaultIrsaRoleArn")
}
helm @vaultArgs

Write-Host "==> Wave 1 — Istio"
helm upgrade --install istio-base istio/base -n istio-system --create-namespace --wait --timeout 10m
helm upgrade --install istiod istio/istiod -n istio-system `
  -f infra/helm/values/istio/values-dev.yaml `
  --wait --timeout 10m
kubectl apply -f infra/helm/values/istio/peer-authentication.yaml

Write-Host "==> Wave 1 — OpenTelemetry Collector"
helm upgrade --install otel-collector open-telemetry/opentelemetry-collector `
  -n rip-system `
  -f infra/helm/charts/otel-collector/values.yaml `
  -f infra/helm/charts/otel-collector/values-dev.yaml `
  --wait --timeout 10m

Write-Host "==> Wave 2 — Argo CD"
helm upgrade --install argocd argo/argo-cd -n argocd --create-namespace `
  -f infra/helm/charts/argocd/values-dev.yaml `
  --wait --timeout 10m
kubectl apply -f infra/argocd/app-projects.yaml
kubectl apply -f infra/argocd/applicationsets/rip-platform.yaml

Write-Host "==> Wave 2 — Monitoring (Grafana + Prometheus)"
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack `
  -n monitoring `
  -f infra/helm/charts/kube-prometheus-stack/values.yaml `
  -f infra/helm/charts/kube-prometheus-stack/values-dev.yaml `
  --wait --timeout 15m

Write-Host "==> Wave 3 — External Secrets Operator"
helm upgrade --install external-secrets external-secrets/external-secrets `
  -n rip-system --create-namespace --set installCRDs=true `
  --wait --timeout 10m

Write-Host "==> Wave 3 — Network policies (after workloads are up)"
kubectl apply -f infra/helm/charts/network-policies/rip-system.yaml

if (-not $SkipVaultBootstrap) {
  Write-Host "==> Step D — Vault bootstrap"
  $bootstrap = Join-Path $PSScriptRoot "vault-bootstrap.ps1"
  if (Test-Path $bootstrap) {
    & $bootstrap
  } else {
    Write-Warning "vault-bootstrap.ps1 not found; configure Vault manually (see docs/runbooks/vault-paths.md)."
  }
}

Write-Host "==> Deployment status"
kubectl get pods -n rip-system
kubectl get pods -n istio-system
kubectl get pods -n argocd
kubectl get pods -n monitoring
kubectl get applications -n argocd 2>$null
kubectl get applicationsets -n argocd 2>$null

Write-Host "Done. Next: Step F — verify GitHub Actions CI + ECR OIDC (workflow_dispatch on Build & Push)."
