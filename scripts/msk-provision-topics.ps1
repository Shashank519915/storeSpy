# MSK topic bootstrap — run after Terraform MSK apply (RIP-1-011)
# TFC cannot reach private MSK brokers; this Job runs inside EKS with IRSA.

param(
  [string]$BootstrapServers = "",
  [string]$MskAdminRoleArn = ""
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$BootstrapDir = Join-Path $RepoRoot "infra\k8s\msk-topic-bootstrap"
Set-Location $RepoRoot

$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

if (-not $BootstrapServers) {
  $BootstrapServers = aws kafka get-bootstrap-brokers --region us-east-1 --cluster-arn $(aws kafka list-clusters --region us-east-1 --query "ClusterInfoList[?ClusterName=='rip-dev-msk'].ClusterArn" --output text) --query "BootstrapBrokerStringSaslIam" --output text
}

if (-not $MskAdminRoleArn) {
  $MskAdminRoleArn = aws iam get-role --role-name rip-dev-msk-admin --query "Role.Arn" --output text
}

if (-not $BootstrapServers -or $BootstrapServers -eq "None") {
  throw "MSK bootstrap brokers not found. Wait for Terraform apply, then retry."
}

Write-Host "Bootstrap servers: $BootstrapServers"
Write-Host "MSK admin role: $MskAdminRoleArn"

# ServiceAccount with IRSA
$sa = Get-Content (Join-Path $BootstrapDir "serviceaccount.yaml") -Raw
$sa = $sa.Replace("REPLACE_MSK_ADMIN_ROLE_ARN", $MskAdminRoleArn)
$sa | kubectl apply -f -

# ConfigMaps
kubectl create configmap msk-topic-bootstrap-config -n rip-system `
  --from-file=client.properties=(Join-Path $BootstrapDir "client.properties") `
  --from-file=topics.json=(Join-Path $BootstrapDir "topics.json") `
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create configmap msk-topic-bootstrap-scripts -n rip-system `
  --from-file=create-topics.py=(Join-Path $BootstrapDir "create-topics.py") `
  --dry-run=client -o yaml | kubectl apply -f -

# Job (patch bootstrap servers)
$job = Get-Content (Join-Path $BootstrapDir "job.yaml") -Raw
$job = $job.Replace("REPLACE_BOOTSTRAP_SERVERS", $BootstrapServers)
kubectl delete job msk-topic-bootstrap -n rip-system --ignore-not-found
$job | kubectl apply -f -

kubectl wait --for=condition=complete job/msk-topic-bootstrap -n rip-system --timeout=600s
kubectl logs -n rip-system job/msk-topic-bootstrap
Write-Host "MSK topics provisioned."
