# Phase 0 Live Deployment Guide

Complete this checklist **after** the Phase 0 PR is merged. Phase 1 cannot start until live exit criteria are met.

## Prerequisites (one-time manual setup)

### 1. Terraform Cloud

1. Create account at https://app.terraform.io
2. Create organization: `rip-platform` (or update `infra/terraform/environments/dev/main.tf` cloud block)
3. Create workspace: `rip-dev` (CLI-driven or VCS-driven)
4. Set workspace variables:
   - `AWS_ACCESS_KEY_ID` (sensitive)
   - `AWS_SECRET_ACCESS_KEY` (sensitive)
   - `AWS_DEFAULT_REGION` = `us-east-1`

### 2. AWS Account

1. Create or use an existing AWS account
2. Create IAM user or role for Terraform with policies:
   - `AdministratorAccess` (dev only) or scoped VPC/EKS/S3/IAM
3. Note your **AWS Account ID** (12 digits)

### 3. GitHub Repository Secrets

In `https://github.com/Shashank519915/storeSpy` → Settings → Secrets and variables → Actions:

| Secret | Value |
|--------|-------|
| `AWS_ACCOUNT_ID` | Your 12-digit AWS account ID |

Optional (for Terraform Cloud VCS):
| Secret | Value |
|--------|-------|
| `TFC_TOKEN` | Terraform Cloud API token |

### 4. GitHub OIDC (after first Terraform apply)

After `terraform apply` creates the `rip-dev-ci-deploy` role, add to workflow if account ID differs from secret.

### 5. Install local tools (recommended)

```powershell
winget install Hashicorp.Terraform
winget install GitHub.cli
aws --version   # AWS CLI v2
```

Authenticate:
```powershell
gh auth login
aws configure
```

---

## Step-by-step deployment

### Step A — Terraform dev environment

```powershell
cd infra/terraform/environments/dev
terraform login          # Terraform Cloud
terraform init
terraform plan
terraform apply
```

**Expected outputs:** `vpc_id`, `eks_cluster_name`, `ci_deploy_role_arn`, `s3_buckets`

**Pass criteria:** Zero unexpected destroys; VPC + EKS + S3 + IAM OIDC created.

### Step B — Configure kubectl for EKS

```powershell
aws eks update-kubeconfig --region us-east-1 --name rip-dev
kubectl get nodes
```

**Pass criteria:** System + workload node groups Ready within 5 min.

### Step C — Deploy platform Helm charts (order matters)

```powershell
# Add Helm repos
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo add argo https://argoproj.github.io/argo-helm
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update

# Create namespace
kubectl create namespace rip-system

# Sync wave 0 — Vault, network policies
helm upgrade --install vault hashicorp/vault -n rip-system -f infra/helm/charts/vault/values.yaml
kubectl apply -f infra/helm/charts/network-policies/rip-system.yaml

# Initialize and unseal Vault (manual — see HashiCorp docs)
# Configure KMS auto-unseal key: alias/rip-vault-unseal

# Sync wave 1 — Istio, OTel, cert-manager
helm upgrade --install istio-base istio/base -n istio-system --create-namespace
helm upgrade --install istiod istio/istiod -n istio-system
kubectl apply -f infra/helm/values/istio/peer-authentication.yaml
helm upgrade --install otel-collector open-telemetry/opentelemetry-collector -n rip-system -f infra/helm/charts/otel-collector/values.yaml

# Sync wave 2 — ArgoCD
helm upgrade --install argocd argo/argo-cd -n argocd --create-namespace
kubectl apply -f infra/argocd/app-projects.yaml
kubectl apply -f infra/argocd/applicationsets/rip-platform.yaml
```

### Step D — Vault configuration

1. Enable namespaces: `rip/dev`, `rip/staging`, `rip/prod`
2. Enable PKI engine → intermediate CA `rip-internal-ca` (24h TTL)
3. Enable Database secrets engine for PostgreSQL (1h TTL)
4. Configure Kubernetes auth per `infra/helm/charts/vault-auth/values.yaml`
5. Deploy External Secrets Operator + `ClusterSecretStore`

See `docs/runbooks/vault-paths.md`.

### Step E — Edge lab (optional for Phase 0 exit, required before Phase 2)

```bash
# On edge NVIDIA node
export K3S_TOKEN=<from-vault>
export WG_CLOUD_ENDPOINT=<bastion-ip>:51820
export WG_CLOUD_PUBLIC_KEY=<from-vault>

ansible-playbook -i inventory/edge.ini infra/ansible/edge-bootstrap.yml
ansible-playbook -i inventory/edge.ini infra/ansible/k3s-install.yml
ansible-playbook -i inventory/edge.ini infra/ansible/wireguard-edge.yml
```

### Step F — Verify CI OIDC

1. Push a commit to `main` (or open PR)
2. Confirm `CI Foundation` workflow passes
3. Confirm `Build & Push` can assume `rip-dev-ci-deploy` role (after ECR repos exist)

---

## Exit criteria checklist

Copy to issue/PR when live deploy is done:

- [ ] Monorepo scaffold merged; CI lint jobs green
- [ ] `rip-dev` Terraform applied
- [ ] Vault HA unsealed; dynamic PostgreSQL secrets tested
- [ ] Istio STRICT mTLS enforced
- [ ] ArgoCD syncing otel-collector
- [ ] K3s lab + GPU + DCGM (if hardware available)
- [ ] SPIRE edge SVIDs (if edge node available)
- [ ] WireGuard 24h soak (if edge node available)
- [ ] GitHub Actions → ECR via OIDC
- [ ] Grafana dashboards live
- [ ] Runbooks approved
- [ ] Design tokens + ESLint rule in CI ✅ (repo scaffold)

---

## When to start Phase 1

Start Phase 1 when:
1. Phase 0 PR is **merged to main**
2. At minimum: **Terraform dev applied + EKS reachable + CI green on main**
3. Full edge/SPIRE/WireGuard can proceed in parallel with Phase 1 event backbone work

Phase 1 plan: `docs/plans/phase-1-event-backbone.md`
