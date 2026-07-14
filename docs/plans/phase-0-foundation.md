# RIP Phase 0: Foundation & Infrastructure as Code
**Prerequisites:** None (program entry point)
**Governance:** code_style.md, design-tokens.md
**Master plan:** rip-execution-plan.md (this is the standalone working copy)


## Phase Objective
Establish the immutable engineering foundation — monorepo skeleton, cloud VPCs, K8s control planes (EKS + K3s reference), Vault HA, SPIFFE/SPIRE identity, CI/CD pipelines, and GitOps — such that every subsequent subsystem deploys into a governed, observable, zero-trust environment. No application logic ships in this phase; only platform primitives.

## Sub-systems Involved
- Turborepo/Nx monorepo (`rip/`)
- Cloud VPC + EKS control plane
- Reference K3s edge cluster (lab)
- HashiCorp Vault HA + PKI mounts
- SPIFFE/SPIRE on edge reference node
- ArgoCD (cloud) + Fleet/ArgoCD Edge agent pattern
- GitHub Actions OIDC → AWS IAM
- OpenTelemetry Collector (daemonset skeleton)
- Terraform remote state (Terraform Cloud)
- Ansible bare-metal edge provisioning playbooks

---

## Granular Tasks

### 0.1 Monorepo Bootstrap
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-0-001 | Initialize Turborepo + pnpm workspaces + Nx project graph with cache keys per language | `turbo.json`, `nx.json`, `pnpm-workspace.yaml` |
| RIP-0-002 | Scaffold directory tree per `code_style.md` §2.1 with placeholder README stubs | `apps/`, `services/`, `packages/`, `infra/` |
| RIP-0-003 | Configure `buf.yaml` with `FILE` breaking rules, `DEFAULT` lint; wire `buf generate` for Go/Python/TS | `packages/proto/buf.yaml` |
| RIP-0-004 | Add shared `packages/ts-config/tsconfig.strict.json` with `strict`, `noUncheckedIndexedAccess` | `packages/ts-config/` |
| RIP-0-005 | Add `.github/workflows/ci-foundation.yml`: lint matrix (golangci-lint, ruff, eslint), `buf lint` | `.github/workflows/` |
| RIP-0-006 | Configure pre-commit hooks: gofmt, black, ruff, eslint, buf format | `.pre-commit-config.yaml` |
| RIP-0-007 | Create ADR template and first ADR: "Turborepo + Nx dual orchestration rationale" | `docs/adr/0001-monorepo-tooling.md` |

### 0.2 Terraform Cloud Foundation
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-0-010 | Terraform Cloud workspace per environment (`rip-dev`, `rip-staging`, `rip-prod`) with remote state locking | Terraform Cloud config |
| RIP-0-011 | Module `infra/terraform/modules/vpc`: multi-AZ VPC, public/private/database subnets, NAT GW, VPC flow logs → S3 | `modules/vpc/` |
| RIP-0-012 | Module `infra/terraform/modules/eks`: EKS 1.29+, managed node groups (system + workload), IRSA enabled | `modules/eks/` |
| RIP-0-013 | Module `infra/terraform/modules/security-baseline`: AWS Config, GuardDuty, CloudTrail → centralized S3 | `modules/security-baseline/` |
| RIP-0-014 | Environment `infra/terraform/environments/dev`: compose VPC + EKS + baseline; CIDR planning doc | `environments/dev/` |
| RIP-0-015 | IAM OIDC provider for GitHub Actions; role `rip-ci-deploy` with least-privilege ECR push + read-only TF plan | `modules/iam-github-oidc/` |
| RIP-0-016 | S3 buckets: `rip-terraform-state` (versioned), `rip-container-registry-mirror`, `rip-edge-image-staging` with encryption + bucket policies | `modules/s3-foundation/` |

### 0.3 Vault HA & PKI
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-0-020 | Deploy Vault HA on EKS via Helm (3 replicas, Raft storage, auto-unseal via AWS KMS) | `infra/helm/charts/vault/` |
| RIP-0-021 | Configure Vault namespaces: `rip/dev`, `rip/staging`, `rip/prod` | Vault policy HCL files |
| RIP-0-022 | Enable Vault PKI engine: intermediate CA `rip-internal-ca`, TTL 24h for service certs | `infra/terraform/modules/vault-pki/` |
| RIP-0-023 | Enable Vault Database Secrets Engine for PostgreSQL dynamic creds (1h TTL) | `infra/terraform/modules/vault-database/` |
| RIP-0-024 | Configure Vault Kubernetes auth: per-service roles bound to K8s SA JWT | `infra/helm/charts/vault-auth/` |
| RIP-0-025 | Deploy External Secrets Operator; `ClusterSecretStore` pointing to Vault | `infra/helm/charts/external-secrets/` |
| RIP-0-026 | Document Vault path convention in runbook | `docs/runbooks/vault-paths.md` |

### 0.4 Kubernetes Platform Services (Cloud EKS)
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-0-030 | Install Istio service mesh: STRICT mTLS PeerAuthentication default-deny | `infra/helm/values/istio/` |
| RIP-0-031 | Deploy ArgoCD with AppProject per bounded context (`portal`, `api`, `reasoning`, `infra`) | `infra/argocd/` |
| RIP-0-032 | Deploy cert-manager with Vault issuer for internal TLS | `infra/helm/charts/cert-manager/` |
| RIP-0-033 | Deploy OpenTelemetry Collector DaemonSet + Gateway; exporters to Tempo + Loki + Prometheus | `infra/helm/charts/otel-collector/` |
| RIP-0-034 | Deploy Prometheus Operator + Grafana + Alertmanager with PagerDuty integration skeleton | `infra/helm/charts/kube-prometheus-stack/` |
| RIP-0-035 | Deploy Loki (distributed mode) + Tempo for trace storage | `infra/helm/charts/loki/`, `tempo/` |
| RIP-0-036 | Define K8s NetworkPolicy default-deny in `rip-system` namespace; explicit allowlist per service | `infra/helm/charts/network-policies/` |

### 0.5 Edge Reference Cluster (K3s Lab)
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-0-040 | Ansible playbook: OS hardening (swap off, ulimits, chrony PTP), NVIDIA driver 535+, container toolkit | `infra/ansible/edge-bootstrap.yml` |
| RIP-0-041 | Ansible playbook: K3s single-node install with SQLite backend, kubeconfig export | `infra/ansible/k3s-install.yml` |
| RIP-0-042 | Deploy NVIDIA GPU Operator on K3s lab node; verify `nvidia.com/gpu` resource | `edge/gpu-operator/values-lab.yaml` |
| RIP-0-043 | Deploy DCGM Exporter DaemonSet; verify `DCGM_FI_DEV_GPU_UTIL` in Prometheus | `edge/gpu-operator/dcgm-exporter.yaml` |
| RIP-0-044 | Deploy SPIRE Server (cloud) + SPIRE Agent (edge); issue SVID for `spiffe://rip.internal/edge/lab/store-00` | `infra/helm/charts/spire/` |
| RIP-0-045 | WireGuard outbound tunnel: edge lab → cloud bastion; no inbound edge ports | `infra/ansible/wireguard-edge.yml` |
| RIP-0-046 | Deploy lightweight ArgoCD agent or Rancher Fleet agent on edge; GitOps reconcile loop | `edge/fleet-crds/agent-install.yaml` |

### 0.6 CI/CD Pipeline Foundation
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-0-050 | GitHub Actions: OIDC assume `rip-ci-deploy` role; ECR repository per service skeleton | `.github/workflows/build-push.yml` |
| RIP-0-051 | Multi-stage Docker base image: `nvidia/cuda:12.1-runtime-ubuntu22.04` + OTel + non-root user | `infra/docker/base-cv-runtime/` |
| RIP-0-052 | Trivy scan gate: Critical/High CVE blocks merge | `.github/workflows/security-scan.yml` |
| RIP-0-053 | ArgoCD ApplicationSet for `apps/*` (sync wave 0 = infra, wave 1 = platform, wave 2 = apps) | `infra/argocd/applicationsets/` |
| RIP-0-054 | Conftest policies: forbid `latest` image tags, forbid secret literals in manifests | `infra/helm/policies/` |

---


### 0.7 Design System Foundation
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-0-055 | Create `packages/ui/tokens/*.css` from this document | `packages/ui/tokens/` |
| RIP-0-056 | Wire Tailwind v4 `@theme` in `apps/portal/app/globals.css` | `apps/portal/app/globals.css` |
| RIP-0-057 | Add ESLint `rip/no-raw-color` rule | `packages/eslint-config/` |
| RIP-0-058 | Document token workflow in `docs/runbooks/design-tokens.md` | `docs/runbooks/design-tokens.md` |

---

## Infrastructure/DevOps Tasks (Phase 0)

| Asset | Technology | Specification |
|-------|------------|---------------|
| VPC | Terraform `modules/vpc` | 3 AZ, /16 cloud CIDR, private EKS subnets, DB subnet group |
| EKS | Terraform `modules/eks` | K8s 1.29, managed NG (m6i.xlarge system, m6i.2xlarge workload) |
| Vault | Helm + KMS auto-unseal | 3-node Raft, audit log → S3 |
| Istio | Helm | STRICT mTLS, ingress gateway for portal only |
| ArgoCD | Helm | SSO via OIDC, repo-creds via Vault |
| K3s Lab | Ansible | Single NVIDIA IGX/RTX node reference image |
| SPIRE | Helm | X.509 SVID rotation 1h |
| OTel | DaemonSet + Gateway | OTLP gRPC :4317, batch processor |
| WireGuard | Ansible | Edge initiates, cloud accepts, `/etc/wireguard/rip0.conf` |
| S3 | Terraform | Versioned buckets, Object Lock prep for WORM (enabled Phase 6) |

---

## Production-Ready Implementation Details (Phase 0)

### SPIFFE/SPIRE Edge Identity Bootstrap
1. SPIRE Server runs in EKS `rip-system` namespace with upstream Vault PKI integration for federation.
2. Edge K3s node runs SPIRE Agent with join token delivered via Vault one-time secret (never committed).
3. Agent attests node via `k8s_psat` plugin; issues SVID `spiffe://rip.internal/edge/<store_id>/<node_id>`.
4. Edge services present SVID for mTLS to cloud Kafka bridge and Vault Agent auth.
5. Rotation: SVID TTL 1h; agent renews at 80% lifetime; failure emits `spire_renewal_failed` metric → P2 alert.

### GitHub Actions OIDC → AWS (No Long-Lived Keys)
1. Configure AWS IAM OIDC provider for `token.actions.githubusercontent.com`.
2. Role trust policy: `sub` = `repo:org/rip:ref:refs/heads/main` for deploy; `pull_request` for plan-only.
3. CI job `permissions: id-token: write` → `aws-actions/configure-aws-credentials` with role `rip-ci-deploy`.
4. ECR push scoped to `rip/*` repositories only.

### WireGuard Edge Tunnel
1. Cloud bastion generates keypair; public key stored in Vault `secret/data/rip/<env>/wireguard/peers/<store_id>`.
2. Edge Ansible role writes `wg0.conf`: `PersistentKeepalive=25`, `AllowedIPs=10.200.0.0/16` (cloud service CIDR).
3. Kafka MSK brokers reachable only via tunnel SG rule: source = WireGuard peer IPs.
4. Tunnel health: `wireguard_latest_handshake_seconds` exported via node_exporter textfile collector.

---

## Testing & Validation (Phase 0)

| Test | Procedure | Pass Criteria |
|------|-----------|---------------|
| TF Plan | `terraform plan` on dev PR | Zero unexpected destroys; cost estimate within budget |
| Vault HA | Kill 1 Vault pod | Cluster remains unsealed; secret read succeeds |
| Vault Dynamic DB | Request creds via K8s SA | Cred works for PostgreSQL; expires after 1h |
| EKS Node Join | Scale NG +1 | Node Ready < 5 min; CNI pods healthy |
| Istio mTLS | `istioctl authn tls-check` | STRICT between two sample services |
| K3s GPU | `kubectl describe node` | `nvidia.com/gpu: 1` allocatable |
| DCGM | Grafana query | GPU metrics visible within 60s of node boot |
| SPIRE | Edge service fetch X.509 | SVID valid; chain to Vault intermediate CA |
| WireGuard | Drop tunnel 60s | Edge alert fires; auto-reconnect on restore |
| ArgoCD | Push manifest change | Sync within 3 min; drift detection active |
| CI OIDC | Run workflow on PR | ECR login without static keys |
| OTel | Emit test span from sample pod | Trace visible in Tempo within 30s |

---

## Exit Criteria (Phase 0)

- [ ] Monorepo scaffold merged; all CI lint jobs green on empty services
- [ ] `rip-dev` Terraform applied: VPC + EKS + S3 + IAM OIDC operational
- [ ] Vault HA cluster unsealed; dynamic PostgreSQL secrets tested
- [ ] Istio STRICT mTLS enforced cluster-wide
- [ ] ArgoCD syncing `infra/helm/charts/otel-collector` to dev EKS
- [ ] K3s lab node provisioned via Ansible; GPU Operator + DCGM healthy
- [ ] SPIRE issuing edge SVIDs; sample mTLS handshake cloud↔edge succeeds
- [ ] WireGuard tunnel stable ≥ 24h soak test with zero unplanned disconnects > 60s
- [ ] GitHub Actions pushing to ECR via OIDC (no static AWS keys in repo)
- [ ] Grafana dashboards: cluster health + GPU lab node + Vault seal status
- [ ] Runbooks: `vault-paths.md`, `edge-bootstrap.md`, `argocd-sync.md` approved by SRE lead


- [ ] `packages/ui/tokens/*.css` created from `design-tokens.md` (primitives, semantic, component, domain, motion, typography, spacing, radius, shadow)
- [ ] Tailwind v4 `@theme` bridge wired in `apps/portal/app/globals.css`
- [ ] ESLint `rip/no-raw-color` rule blocks raw hex and ad-hoc Tailwind color literals in CI
- [ ] Token workflow runbook `docs/runbooks/design-tokens.md` approved
- [ ] WCAG 2.1 AA contrast pairs verified for light and dark semantic mappings

**Phase 0 outputs are strict dependencies for Phase 1.**

---

