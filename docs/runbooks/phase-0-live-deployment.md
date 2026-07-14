# Phase 0 Live Deployment Guide

Complete this checklist **after** the Phase 0 PR is merged. Phase 1 cannot start until live exit criteria are met.

## Prerequisites (one-time manual setup)

### 1. Terraform Cloud (HCP Terraform)

#### 1a. Organization & workspace

1. Create account at https://app.terraform.io
2. Create organization: **`rip-platform`**
3. Create workspace: **`rip-dev`**
   - Can start as CLI-driven; VCS is connected in step 1c below
4. **Execution Mode:** keep **Remote** (default) when using VCS (Plan B — recommended)

#### 1b. AWS credentials (workspace variables)

In `rip-dev` → **Variables** → **+ Add variable** — add each as **Environment variable**:

| Key | Value | Sensitive |
|-----|-------|-----------|
| `AWS_ACCESS_KEY_ID` | From IAM user `terraform-rip-dev` | Yes |
| `AWS_SECRET_ACCESS_KEY` | From IAM user `terraform-rip-dev` | Yes |
| `AWS_DEFAULT_REGION` | `us-east-1` | No |

**Do not** use Terraform variable category for AWS keys — use **Environment variable**.

> **TFC_TOKEN:** Not required for VCS workflow. Skip unless you automate Terraform via API later.

#### 1c. Connect GitHub VCS (Plan B — recommended)

This fixes the `Unreadable module directory ../../modules` error: HCP Terraform clones the **full repo**, so `../../modules` resolves correctly.

1. `rip-dev` → **Settings** → **Version Control**
2. Connect provider: **GitHub**
3. Authorize HashiCorp Terraform Cloud app on your GitHub account
4. Repository: **`Shashank519915/storeSpy`**
5. Configure:

| Setting | Value |
|---------|-------|
| **Terraform working directory** | `infra/terraform/environments/dev` |
| **VCS branch** | *(leave empty = default branch `main`)* |
| **VCS trigger type** | Branch-based |
| **Automatic run triggering** | Always trigger runs |
| **Automatic speculative plans** | Enabled (plans on PRs) |
| **Auto-apply API, UI, & VCS runs** | Enabled *(or disable for first run if you want manual Apply)* |
| **Include submodules on clone** | Unchecked |

6. Click **Update VCS settings**

7. Confirm **General** → **Execution Mode** is **Remote**

#### 1d. Alternative — Local execution (Plan A)

Use only if you cannot connect VCS. Not recommended long-term.

1. **Settings** → **General** → **Execution Mode** → **Local** → Save
2. Configure AWS on your PC: `aws configure` (same keys as IAM user)
3. Run `terraform plan` / `apply` from your terminal locally
4. State still stored in HCP Terraform; credentials come from your machine, not workspace variables

---

### 2. AWS Account

#### 2a. Create IAM user for Terraform

1. AWS Console → **IAM** → **Users** → **Create user**
2. User name: **`terraform-rip-dev`**
3. **Do not** enable console access (programmatic access only)
4. Permissions: **Attach policies directly** → **`AdministratorAccess`**

> **What does "dev only" mean?** It is **our guidance**, not an AWS option. It means: use full admin only in this **development** AWS account. For production later, use scoped policies — not `AdministratorAccess`.

5. Click **Create user**

#### 2b. Create access keys (after user exists)

Access keys are **not** created in the 3-step wizard.

1. Open user **`terraform-rip-dev`**
2. **Security credentials** tab
3. **Access keys** → **Create access key**
4. Use case: **Command Line Interface (CLI)**
5. Copy **Access key ID** and **Secret access key** (secret shown once)
6. Paste into Terraform Cloud workspace variables (§1b)

#### 2c. Note Account ID

AWS Console → username dropdown → copy **Account ID** (12 digits) for GitHub secret below.

---

### 3. GitHub Repository Secrets

`https://github.com/Shashank519915/storeSpy` → **Settings** → **Secrets and variables** → **Actions**:

| Secret | Value |
|--------|-------|
| `AWS_ACCOUNT_ID` | Your 12-digit AWS account ID |

---

### 4. Install local tools on your PC

**Where commands run:** Steps B–F below run in a **local PowerShell terminal** on your Windows machine (Cursor terminal, Windows Terminal, or PowerShell). They do **not** run in HCP Terraform, the AWS web console, or GitHub Actions.

| Tool | Required for | Install |
|------|----------------|---------|
| AWS CLI | `aws eks update-kubeconfig`, `aws configure` | `winget install Amazon.AWSCLI` |
| kubectl | `kubectl get nodes`, Helm (Step C) | Docker Desktop includes it, or `winget install Kubernetes.kubectl` |
| Helm | Step C platform charts | `winget install Helm.Helm` |
| Terraform | Optional — local debugging only | `winget install Hashicorp.Terraform` |

After installing, **refresh PATH** (or restart Cursor):

```powershell
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
aws --version
kubectl version --client
```

Configure AWS CLI once (same keys as `terraform-rip-dev`):

```powershell
aws configure
# AWS Access Key ID:     <from terraform-rip-dev IAM user>
# AWS Secret Access Key: <from terraform-rip-dev IAM user>
# Default region name:   us-east-1
# Default output format: json
```

> **AWS Console region:** Always switch to **US East (N. Virginia) `us-east-1`** when viewing EKS/VPC resources. The console defaults to your nearest region (e.g. Stockholm) and will show **0 clusters** even when `rip-dev` exists.

---

### 5. GitHub OIDC (after first Terraform apply)

After `terraform apply` creates the `rip-dev-ci-deploy` role, GitHub Actions can push to ECR without static keys. Verify `AWS_ACCOUNT_ID` secret matches your account.

---

## Step-by-step deployment

### Step A — Terraform dev environment

#### Option 1: VCS workflow (Plan B — after §1c is saved)

**First run — trigger from HCP Terraform UI:**

1. Open https://app.terraform.io/app/rip-platform/rip-dev
2. Click **Start new plan** (or **Actions** → **Start new run**)
3. Choose **Plan only** for first run (review before apply)
4. Review plan output in UI (~50+ resources: VPC, EKS, S3, IAM OIDC, etc.)
5. If plan looks correct → **Confirm & apply** (or start new **Plan and apply** run)

**Subsequent runs — automatic:**

- Push to `main` touching `infra/terraform/**` → VCS triggers plan
- With auto-apply enabled → successful plans apply automatically
- PRs → speculative plan only (no apply)

**Expected outputs:** `vpc_id`, `eks_cluster_name`, `ci_deploy_role_arn`, `s3_buckets`

**Pass criteria:** Zero unexpected destroys; VPC + EKS + S3 + IAM OIDC created.

**Duration:** EKS cluster + node groups can take **15–30 minutes**.

#### Dev environment decisions (as deployed)

These choices are encoded in `infra/terraform/environments/dev/main.tf` and module defaults. Documented here so you know what was applied and what to change later.

| Decision | Dev choice (now) | Why |
|----------|------------------|-----|
| **AWS region** | `us-east-1` | TFC workspace var `AWS_DEFAULT_REGION`; all resources live here |
| **HCP Terraform** | VCS + auto-apply on `main` | Full repo clone resolves `../../modules`; push triggers apply |
| **EKS Kubernetes version** | `1.31` | `1.29` unsupported in AWS by Jul 2026 |
| **EKS node instance types** | `t3.micro` (system + workload) | New AWS accounts only allow free-tier-eligible types until billing is verified |
| **EKS node counts** | 1 system + 1 workload | Minimal cost; enough to bootstrap Helm/platform charts |
| **GuardDuty** | Disabled (`enable_guardduty = false`) | New accounts hit `SubscriptionRequiredException` until GuardDuty is subscribed |
| **CI deploy ECR policy** | Wildcard `arn:aws:ecr:us-east-1:*:repository/rip/*` | No ECR repos exist yet at first apply |
| **Config / CloudTrail** | S3 bucket policies added in module | Required for delivery channel and trail creation |

#### Upgrading to paid / production-tier sizing (later)

After you add a **payment method** in AWS Billing and want real workload capacity, edit `infra/terraform/environments/dev/main.tf` (or create `rip-staging` / `rip-prod` workspaces):

```hcl
module "eks" {
  # ...
  cluster_version         = "1.31"   # bump when AWS deprecates; check EKS docs
  system_instance_types   = ["m6i.xlarge"]
  workload_instance_types = ["m6i.2xlarge"]
  system_desired_size     = 2
  workload_desired_size   = 3
}

module "security_baseline" {
  # ...
  enable_guardduty = true   # after subscribing in GuardDuty console once
}
```

Push to `main` → VCS triggers plan/apply. Expect node group **replace** (rolling) when instance types change.

| Tier | Suggested instance types | Node counts | Notes |
|------|------------------------|-------------|-------|
| **Dev (bootstrap)** | `t3.micro` | 1 + 1 | Current; fine for Helm smoke test |
| **Dev (paid)** | `t3.medium` or `m6i.large` | 2 + 2 | Comfortable for Vault + Istio + ArgoCD |
| **Staging** | `m6i.xlarge` | 2 + 3 | Module defaults in `modules/eks` |
| **Production** | `m6i.2xlarge`+ | Per capacity plan | Separate workspace `rip-prod` |

#### Option 2: Local CLI workflow (Plan A)

```powershell
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

cd C:\Users\aksanand\Desktop\storeSpy\infra\terraform\environments\dev
terraform login
terraform init
terraform plan
terraform apply
```

Requires **Local** execution mode (§1d) and `aws configure` on your PC.

---

### Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `Unreadable module directory ../../modules` | CLI remote run without full repo | Connect VCS (§1c) **or** switch to Local execution (§1d) |
| `terraform: command not found` | PATH not refreshed after install | Restart Cursor; or refresh PATH: `$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")` |
| `terraform: command not found` (fallback) | WinGet shim not in PATH | `& "$env:LOCALAPPDATA\Microsoft\WinGet\Links\terraform.exe" version` |
| Plan fails with AWS auth error | Missing/wrong workspace variables | Re-check §1b; keys must be **Environment variables**, Sensitive checked |
| VCS not triggering runs | Working directory wrong | Must be exactly `infra/terraform/environments/dev` |
| `not eligible for Free Tier` on EKS node group | New account without billing verification | Dev uses `t3.micro` in `main.tf`; add a payment method in AWS Billing to use `m6i.*` |
| EKS node group `CREATE_FAILED` after instance fix | Prior failed node groups still exist | EKS console → `rip-dev` → Compute → delete `rip-dev-system` and `rip-dev-workload`, then re-apply |
| `aws: command not found` | AWS CLI not installed or PATH stale | `winget install Amazon.AWSCLI`, refresh PATH (§4), restart terminal |
| EKS console shows 0 clusters | Wrong AWS region in browser | Switch console to **US East (N. Virginia) `us-east-1`** |

---

### Step B — Configure kubectl for EKS (local PowerShell)

Run these on **your PC** in PowerShell (Cursor integrated terminal is fine). Prerequisites: §4 (AWS CLI installed + `aws configure` done).

```powershell
# Refresh PATH if you just installed AWS CLI
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# Merge rip-dev kubeconfig into ~/.kube/config
aws eks update-kubeconfig --region us-east-1 --name rip-dev

# Verify cluster API and nodes
kubectl get nodes
kubectl get nodes -o wide
```

**Expected output:** 2 nodes in `Ready` state (labels `rip.io/node-pool=system` and `workload`).

**Pass criteria:** All nodes Ready within 5 min of successful Terraform apply.

**Optional sanity check without kubectl:**

```powershell
aws eks describe-cluster --region us-east-1 --name rip-dev --query "cluster.status"
# Should print: "ACTIVE"
```

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

Progress as of live dev deploy (Jul 2026). Copy to issue/PR when fully done.

- [x] Monorepo scaffold merged; CI lint jobs green
- [x] `rip-dev` Terraform applied (VPC, EKS, S3, IAM OIDC, Config, CloudTrail)
- [x] EKS reachable — `kubectl get nodes` shows 2× Ready (`t3.micro`, K8s 1.31)
- [ ] Vault HA unsealed; dynamic PostgreSQL secrets tested — **Step C + D**
- [ ] Istio STRICT mTLS enforced — **Step C**
- [ ] ArgoCD syncing otel-collector — **Step C**
- [ ] K3s lab + GPU + DCGM (if hardware available) — **Step E, optional**
- [ ] SPIRE edge SVIDs (if edge node available) — **Step E, optional**
- [ ] WireGuard 24h soak (if edge node available) — **Step E, optional**
- [ ] GitHub Actions → ECR via OIDC — **Step F**
- [ ] Grafana dashboards live — **Step C (kube-prometheus-stack)**
- [x] Runbooks: `phase-0-live-deployment.md` updated with dev decisions + troubleshooting
- [x] Design tokens + ESLint rule in CI ✅ (repo scaffold)

**Minimum gate to start Phase 1:** Terraform applied + EKS reachable + CI green on `main`. Platform Helm (Step C) can overlap with early Phase 1 work but Vault + ArgoCD are needed before app deploys.

---

## When to start Phase 1

Start Phase 1 when:
1. Phase 0 PR is **merged to main**
2. At minimum: **Terraform dev applied + EKS reachable + CI green on main**
3. Full edge/SPIRE/WireGuard can proceed in parallel with Phase 1 event backbone work

Phase 1 plan: `docs/plans/phase-1-event-backbone.md`
