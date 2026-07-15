# Phase 1 Live Deployment Guide

Deploy the **event backbone and data layer** on `rip-dev` after Phase 0 exit criteria are met.

**Plan reference:** `docs/plans/phase-1-event-backbone.md`  
**Toggle reference:** `docs/runbooks/feature-toggles.md`

---

## Prerequisites

| Requirement | How to verify |
|-------------|---------------|
| Phase 0 minimum gate | Terraform applied, EKS reachable, Vault + ArgoCD + External Secrets healthy |
| HCP Terraform `rip-dev` | VCS connected; working directory `infra/terraform/environments/dev` |
| Local tools | AWS CLI, `kubectl`, `helm`, `psql` (PostgreSQL client) |
| Phase 0 platform | `.\scripts\phase0-deploy-platform.ps1` completed successfully |

```powershell
kubectl get nodes
kubectl get pods -n rip-system
aws eks describe-cluster --region us-east-1 --name rip-dev --query "cluster.status"
```

---

## Local scripts — where and when to run

All deploy scripts are run from the **repo root** in PowerShell (Cursor terminal is fine):

```powershell
cd C:\Users\aksanand\Desktop\storeSpy
```

| Order | Script | When |
|-------|--------|------|
| **1** | `.\scripts\phase0-deploy-platform.ps1` | **Required first** — installs Vault, Istio, ArgoCD, OTel, External Secrets on EKS |
| **2** | *(wait for TFC apply)* | RDS + infra from Terraform |
| **3** | `.\scripts\phase1-deploy-platform.ps1` | **After** Phase 0 is healthy **and** RDS Terraform apply succeeded |

**If you skipped Phase 0:** run `phase0-deploy-platform.ps1` before `phase1-deploy-platform.ps1`. Phase 1 assumes Vault, `rip-system` namespace, and kubectl access already exist.

**Prerequisites on your PC:** AWS CLI configured (`aws configure`), `kubectl`, `helm`, and `psql` for migrations.

```powershell
# Quick check before Phase 1
aws eks update-kubeconfig --region us-east-1 --name rip-dev
kubectl get pods -n rip-system
```

---

## Feature toggles — what to change and where

Phase 1 uses **two layers** of toggles. AWS resources use Terraform; EKS runtime components use YAML + deploy script.

### Layer 1 — Terraform (HCP Terraform workspace variables)

Open **HCP Terraform** → org `rip-platform` → workspace **`rip-dev`** → **Variables** → add as **Terraform** category (not Environment):

| Variable | Type | Default | Change when |
|----------|------|---------|-------------|
| `enable_msk` | bool | `false` | AWS MSK subscription is active (UPI mandate settled) |
| `enable_rds` | bool | `true` | Keep `true` for PostgreSQL path; set `false` only to tear down RDS |

**Alternative:** edit defaults in `infra/terraform/environments/dev/feature-toggles.tf` and push to `main`.

**Source of truth file:** `infra/terraform/environments/dev/feature-toggles.tf`  
**Example vars file:** `infra/terraform/environments/dev/terraform.tfvars.example`

After any Terraform toggle change:

1. Push to `main` (VCS auto-plan) **or** trigger **Start new run** in TFC
2. Review plan → **Apply**
3. Confirm outputs in TFC: `feature_flags`, `rds_endpoint`, `kafka_bootstrap_servers`

### Layer 2 — Runtime / Helm (`feature-flags.yaml`)

Edit **`infra/config/dev/feature-flags.yaml`** before running the Phase 1 deploy script:

```yaml
enable_msk: false              # mirrors TFC enable_msk (informational)
enable_rds: true               # mirrors TFC enable_rds (informational)
enable_incluster_kafka: false  # single-broker Kafka on EKS when MSK is off
enable_schema_registry: false  # Confluent Schema Registry
enable_debezium: false         # Kafka Connect + Debezium outbox connector
```

| Flag | Set `true` when | Pod budget note |
|------|-----------------|-----------------|
| `enable_incluster_kafka` | Testing Debezium/outbox **before** MSK is live | +1 Kafka broker (~512Mi) |
| `enable_schema_registry` | Kafka bootstrap exists (MSK or in-cluster) | +1 pod (~256Mi) |
| `enable_debezium` | Kafka + RDS both live | +1 Connect worker (~512Mi) |

**Deploy script reads this file:** `scripts/phase1-deploy-platform.ps1`

### Kafka bootstrap resolution (automatic)

| `enable_msk` (TFC) | `enable_incluster_kafka` (YAML) | Bootstrap servers | Auth |
|--------------------|----------------------------------|-------------------|------|
| `false` | `false` | None — RDS + outbox only | — |
| `false` | `true` | `kafka-dev.rip-system.svc.cluster.local:9092` | PLAINTEXT |
| `true` | `false` | TFC output `msk_bootstrap_brokers_sasl_iam` | AWS_MSK_IAM |
| `true` | `true` | MSK wins (in-cluster ignored) | AWS_MSK_IAM |

---

## Deployment paths

### Path A — RDS only (recommended now; MSK off)

**Toggles:**

```
TFC:  enable_msk=false, enable_rds=true
YAML: enable_incluster_kafka=false, enable_schema_registry=false, enable_debezium=false
```

**Steps:** §1 → §2 → §3 → §4 (skip §5–§7)

Delivers: PostgreSQL + PostGIS schemas, PgBouncer, outbox table, Secrets Manager creds.

### Path B — RDS + in-cluster Kafka (Debezium dev test)

**Toggles:**

```
TFC:  enable_msk=false, enable_rds=true
YAML: enable_incluster_kafka=true, enable_schema_registry=true, enable_debezium=true
```

**Steps:** §1 → §2 → §3 → §4 → §5 → §6 → §7

Use when you want end-to-end outbox → Kafka without paying for MSK yet. Watch `t3.small` pod capacity (may need node upgrade).

### Path C — Production-like (MSK live)

**Toggles:**

```
TFC:  enable_msk=true, enable_rds=true
YAML: enable_incluster_kafka=false, enable_schema_registry=true, enable_debezium=true
```

**Steps:** §1 → §2 → §3 → §4 → §5 (MSK topics) → §6 → §7

**MSK enable checklist:**

1. Confirm no `SubscriptionRequiredException` on a speculative TFC plan with `enable_msk=true`
2. Set `enable_msk=true` in TFC → apply (~20–30 min)
3. Run `.\scripts\msk-provision-topics.ps1`
4. Set `enable_incluster_kafka: false` in YAML
5. Re-run `.\scripts\phase1-deploy-platform.ps1 -KafkaBootstrap "<msk-bootstrap>"`

---

## Step-by-step

### §1 — Push infra and apply Terraform

```powershell
# From repo root — commit Phase 1 infra, push to main
git push origin main
```

In HCP Terraform, confirm the run:

- **Creates** RDS `rip-dev-postgres` when `enable_rds=true`
- **Destroys** partial MSK resources when `enable_msk=false`
- **Skips** MSK modules entirely when `enable_msk=false`

**Pass criteria:** Run applied; output `rds_endpoint` is non-null.

```powershell
# Optional — verify RDS from CLI (after apply completes)
aws rds describe-db-instances --db-instance-identifier rip-dev-postgres `
  --query "DBInstances[0].DBInstanceStatus" --output text
# Expected: available
```

### §2 — Verify Secrets Manager

RDS Terraform writes credentials to **`rip-dev/rds/postgres`**:

```powershell
aws secretsmanager get-secret-value --secret-id rip-dev/rds/postgres `
  --query SecretString --output text | ConvertFrom-Json
```

Fields: `host`, `port`, `database`, `username`, `password`.

### §3 — Run Phase 1 platform deploy

```powershell
.\scripts\phase1-deploy-platform.ps1
```

This script (toggle-aware):

1. Reads `infra/config/dev/feature-flags.yaml`
2. Discovers RDS endpoint (CLI or `-RdsEndpoint`)
3. Deploys **PgBouncer** → RDS (when RDS exists)
4. Runs **migrations** `001`–`006` via `run-rds-migrations.ps1`
5. Optionally deploys **kafka-dev**, **Schema Registry**, **Debezium** per YAML flags

**Manual migration only:**

```powershell
.\scripts\run-rds-migrations.ps1
```

**Pass criteria:**

```powershell
# PgBouncer pod running
kubectl get pods -n rip-system -l app.kubernetes.io/name=pgbouncer

# PostGIS enabled (from a machine with psql + secret access)
.\scripts\run-rds-migrations.ps1  # idempotent — safe to re-run
```

### §4 — Vault database dynamic credentials (after RDS live)

```powershell
.\scripts\vault-database-bootstrap.ps1
```

Configures:

- Vault Database secrets engine → RDS PostgreSQL
- Dynamic creds path: `database/creds/rip-postgresql`
- `twin-api` role → `twin` schema only (RIP-1-047)

See `docs/runbooks/vault-paths.md`.

### §5 — MSK topics (Path C only)

When `enable_msk=true` and cluster is **ACTIVE**:

```powershell
.\scripts\msk-provision-topics.ps1
```

Confirms topic Job completes in `rip-system`:

```powershell
kubectl get job msk-topic-bootstrap -n rip-system
kubectl logs job/msk-topic-bootstrap -n rip-system
```

Topic catalog: `docs/runbooks/kafka-topic-catalog.md`

### §6 — Schema Registry (when Kafka bootstrap exists)

Enabled via `enable_schema_registry: true` in YAML, or manually:

```powershell
# In-cluster Kafka
$bootstrap = "kafka-dev.rip-system.svc.cluster.local:9092"

# MSK (from TFC sensitive output)
# $bootstrap = "<paste msk_bootstrap_brokers_sasl_iam>"

helm upgrade --install schema-registry confluentinc/schema-registry -n rip-system `
  -f infra/helm/charts/schema-registry/values.yaml `
  -f infra/helm/charts/schema-registry/values-dev.yaml `
  --set kafka.bootstrapServers=$bootstrap `
  --wait --timeout 10m
```

Serde runbook: `docs/runbooks/kafka-serde.md`

### §7 — Debezium outbox (when Kafka + RDS exist)

1. Set `enable_debezium: true` in `feature-flags.yaml`
2. Re-run `.\scripts\phase1-deploy-platform.ps1`
3. Apply connector (after Connect REST API is up):

```powershell
kubectl port-forward -n rip-system svc/kafka-connect 8083:8083
curl -X POST -H "Content-Type: application/json" `
  --data "@infra/helm/charts/kafka-connect/debezium-outbox.json" `
  http://localhost:8083/connectors
```

4. Verify with event injector:

```powershell
# Build/run locally against PgBouncer or RDS
cd apps/event-injector
go run . -event-type twin.mutations.layout-changed -aggregate-id <store-uuid>
```

Connector spec: `infra/helm/charts/kafka-connect/debezium-outbox.json`

---

## Toggle change cheat sheet

| Goal | TFC change | YAML change | Re-run |
|------|------------|-------------|--------|
| Start RDS only | `enable_rds=true` | all kafka flags `false` | push → apply → `phase1-deploy-platform.ps1` |
| Add dev Kafka | — | `enable_incluster_kafka=true` | `phase1-deploy-platform.ps1` |
| Add Schema Registry | — | `enable_schema_registry=true` + kafka path | `phase1-deploy-platform.ps1` |
| Add Debezium | — | `enable_debezium=true` | `phase1-deploy-platform.ps1` + connector POST |
| Switch to MSK | `enable_msk=true` | `enable_incluster_kafka=false` | push → apply → `msk-provision-topics.ps1` → `phase1-deploy-platform.ps1 -KafkaBootstrap "..."` |
| Tear down MSK | `enable_msk=false` | — | push → apply (destroys cluster) |
| Tear down RDS | `enable_rds=false` | — | push → apply (**data loss** — dev only) |

---

## Exit criteria checklist (Phase 1 — incremental)

Copy to issue/PR as you complete each path.

### Path A minimum (current target)

- [ ] `enable_rds=true` applied; `rds_endpoint` output populated
- [ ] Migrations `001`–`006` applied; PostGIS extension present
- [ ] PgBouncer serving `rip-system` on port 5432
- [ ] Vault database engine configured (`vault-database-bootstrap.ps1`)
- [ ] `outbox` table exists in `public` schema
- [ ] Protobuf CI green (`schema-registry.yml` workflow)

### Path B add-ons (in-cluster Kafka)

- [ ] `kafka-dev` pod Running in `rip-system`
- [ ] Schema Registry healthy (if enabled)
- [ ] Debezium connector RUNNING; outbox row → Kafka topic
- [ ] `event-injector` produces test event

### Path C add-ons (MSK)

- [ ] MSK cluster ACTIVE; all domain + DLQ topics created
- [ ] MSK IAM roles present (`msk_admin`, producer, consumer)
- [ ] End-to-end Serde with Schema Registry

### Deferred (later Phase 1 sections)

- [ ] ClickHouse ingest (§1.6) — requires Kafka
- [ ] TimescaleDB (§1.7)
- [ ] Qdrant (§1.8)
- [ ] Redis Cluster (§1.9)
- [ ] MinIO (§1.10)
- [ ] Edge bridge (§1.3) — Phase 2 edge lab
- [ ] Grafana outbox lag alert (§1.4) — monitoring deferred from Phase 0

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `SubscriptionRequiredException` on apply | MSK not subscribed | Keep `enable_msk=false`; use Path B or wait for billing |
| RDS apply fails on subnet | VPC module not applied | Re-apply full stack |
| `psql` connection timeout | Security group or wrong endpoint | Use RDS endpoint from Secrets Manager; ensure client in VPC or use SSM port-forward |
| PgBouncer CrashLoop | Missing password | Re-apply RDS TF or pass secret to helm `--set` |
| Kafka deploy pending | Insufficient pod capacity on `t3.small` | Scale node group or disable `enable_incluster_kafka` |
| Debezium no messages | Connector not applied / slot missing | POST connector JSON; check `rip_outbox_slot` replication slot |
| Vault DB creds fail | Engine not bootstrapped | Run `vault-database-bootstrap.ps1` after RDS live |

---

## When to start Phase 2

Start Phase 2 (`docs/plans/phase-2-edge-cv.md`) when:

1. Path A exit criteria met (RDS + schemas + outbox)
2. At least one Kafka path verified (Path B or C) for event flow
3. Phase 0 Step E edge lab hardware available (optional parallel track)
