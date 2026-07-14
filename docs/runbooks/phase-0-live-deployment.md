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

### 4. Install local tools (optional with VCS workflow)

VCS workflow runs plan/apply in HCP Terraform — local Terraform is optional for day-to-day ops.

```powershell
winget install Hashicorp.Terraform   # optional — for local debugging
winget install Amazon.AWSCLI         # required for Step B (kubectl/EKS)
winget install GitHub.cli            # optional
```

After first `terraform apply`, configure AWS CLI for kubectl:

```powershell
aws configure
# Same Access Key ID + Secret as terraform-rip-dev
# Region: us-east-1
```

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

---

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
