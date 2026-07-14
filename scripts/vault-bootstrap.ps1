# Vault bootstrap for Phase 0 Step D - run after vault pod is Running
$ErrorActionPreference = "Continue"

$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

Write-Host "Waiting for vault-0 pod..."
kubectl wait --for=condition=ready pod/vault-0 -n rip-system --timeout=300s

$status = kubectl exec -n rip-system vault-0 -- vault status -format=json 2>$null | ConvertFrom-Json
if ($status.initialized -eq $false) {
  Write-Host "Initializing Vault (KMS auto-unseal)..."
  kubectl exec -n rip-system vault-0 -- vault operator init -format=json | Out-File -Encoding utf8 vault-init.json
  Write-Host "Saved init output to vault-init.json - store recovery keys offline, then delete this file."
} else {
  Write-Host "Vault already initialized."
}

Write-Host "Checking seal status..."
kubectl exec -n rip-system vault-0 -- vault status

$rootToken = $null
if (Test-Path vault-init.json) {
  $init = Get-Content vault-init.json -Raw | ConvertFrom-Json
  $rootToken = $init.root_token
} else {
  $rootToken = Read-Host "Enter Vault root token (if already initialized)"
}

if (-not $rootToken) {
  Write-Warning "No root token; skipping policy/namespace setup."
  exit 0
}

$envVars = "VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=$rootToken"

function VaultExec([string]$cmd) {
  kubectl exec -n rip-system vault-0 -- sh -c "$envVars $cmd"
}

Write-Host "Enabling KV v2 secret paths..."
VaultExec "vault secrets enable -path=secret kv-v2" 2>$null
foreach ($path in @("rip/dev", "rip/staging", "rip/prod")) {
  VaultExec "vault kv put secret/$path/bootstrap initialized=true" 2>$null
}

Write-Host "Enabling PKI..."
VaultExec "vault secrets enable -path=pki_int pki" 2>$null
VaultExec "vault secrets tune -max-lease-ttl=87600h pki_int" 2>$null

Write-Host "Enabling Kubernetes auth..."
VaultExec "vault auth enable kubernetes" 2>$null
$saJwt = kubectl exec -n rip-system vault-0 -- cat /var/run/secrets/kubernetes.io/serviceaccount/token
$k8sHost = kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}'
kubectl exec -n rip-system vault-0 -- sh -c "$envVars vault write auth/kubernetes/config token_reviewer_jwt='$saJwt' kubernetes_host='$k8sHost' kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"

Write-Host "Creating external-secrets policy and role..."
kubectl exec -n rip-system vault-0 -- sh -c "printf '%s\n' 'path \"secret/data/*\" {' '  capabilities = [\"read\"]' '}' > /tmp/external-secrets.hcl"
VaultExec "vault policy write external-secrets /tmp/external-secrets.hcl" 2>$null
VaultExec "vault write auth/kubernetes/role/external-secrets bound_service_account_names=external-secrets bound_service_account_namespaces=rip-system policies=default,external-secrets ttl=1h" 2>$null

Write-Host "Applying ClusterSecretStore..."
kubectl apply -f infra/helm/charts/external-secrets/cluster-secret-store.yaml

Write-Host "Vault bootstrap complete."
