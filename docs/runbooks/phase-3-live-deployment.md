# Phase 3 Live Deployment — Digital Twin (cloud path)

Deploy twin schema extensions and `twin-api` on `rip-dev` after Phase 1 Path A and Phase 2 cloud pipeline are complete.

**Plan:** `docs/plans/phase-3-digital-twin.md`  
**Phase 2 prerequisite:** Wired edge pipeline (`docs/runbooks/phase-2-cloud-dev.md`)

---

## Prerequisites

| Requirement | Status on rip-dev |
|-------------|-----------------|
| RDS + PostGIS | Done (Phase 1) |
| Migrations 001-006 | Done |
| PgBouncer | Done |
| Vault DB engine | Done |
| Edge pipeline -> outbox | Done (`run-edge-pipeline.ps1`) |

**Deferred:** Kafka twin projector, spatial-query consumer, Redis spatial cache (need MSK).

---

## Toggle state (unchanged)

| Toggle | Value | Notes |
|--------|-------|-------|
| `enable_msk` | `false` | Twin mutations stay in outbox until Debezium |
| `enable_edge_hardware` | `false` | Homography stub JSON, not edge GitOps |
| `enable_rds_outbox_sink` | `true` | Edge + twin-api write outbox |

---

## Step 1 — Apply Phase 3 migrations (020-025)

Migrations add `twin.nodes`, `twin.edges`, `twin.cameras`, `twin.versions`, indexes, and dev lab seed.

```powershell
# Terminal 1 — port-forward
kubectl port-forward svc/pgbouncer -n rip-system 15432:5432

# Terminal 2
cd C:\Users\aksanand\Desktop\storeSpy
$env:Path = "C:\Program Files\PostgreSQL\17\bin;" + $env:Path
.\scripts\run-rds-migrations.ps1 -RdsEndpoint localhost -Port 15432
```

Applies **001-025** idempotently (001-006 skip if already applied).

**Verify seed:**

```powershell
$env:PGPORT = "15432"
psql -h localhost -U rip_admin -d rip -c "SELECT external_id FROM retail.stores WHERE external_id='store-dev-01';"
psql -h localhost -U rip_admin -d rip -c "SELECT external_id FROM twin.cameras;"
```

---

## Step 2 — Run twin-api locally (optional)

```powershell
# Build DATABASE_URL from Secrets Manager + port-forward (same as migrations)
$secret = aws secretsmanager get-secret-value --secret-id rip-dev/rds/postgres --query SecretString --output text | ConvertFrom-Json
$env:DATABASE_URL = "postgresql://$($secret.username):$($secret.password)@localhost:15432/$($secret.database)?sslmode=disable"

cd apps\twin-api
go run . -addr :8081
```

**Test mutation (writes outbox row):**

```powershell
Invoke-RestMethod -Method POST -Uri "http://localhost:8081/api/twin/store-dev-01/mutations/shelf-moved" `
  -ContentType "application/json" `
  -Body '{"shelf_id":"shelf-a1","world_x":2.1,"world_y":4.0,"twin_version":2}'
```

---

## Step 3 — End-to-end cloud paths (no Kafka)

| Path | Command | Lands in |
|------|---------|----------|
| CV pickup | `.\scripts\run-edge-pipeline.ps1` | `outbox` (vision.interaction.ProductPickedUp) |
| Twin mutation | `POST .../shelf-moved` | `outbox` (twin.mutations.shelf-moved) |
| Golden check | `.\scripts\run-edge-pipeline.ps1 -StdoutOnly` + validate | CI `cv-golden.yml` |

When MSK is enabled later: Debezium routes outbox rows to Kafka topics automatically.

---

## What is deferred (Phase 3)

| Item | Blocked by |
|------|------------|
| `twin-projector` Kafka consumer | MSK / in-cluster Kafka |
| `spatial-query` enrichment service | Kafka consumer |
| Raycasting coverage jobs | twin-api deployed on EKS (optional later) |
| Fleet GitOps homography push | Edge hardware |
| Time-travel API full replay | Projector + snapshot cadence |

---

## Exit criteria (Phase 3 cloud dev — incremental)

- [ ] Migrations 020-025 applied on rip-dev
- [ ] Dev lab store `store-dev-01` seeded
- [ ] `twin.cameras` has `cam-virtual-01` with homography
- [ ] `twin-api` shelf-moved mutation writes outbox
- [ ] Edge pipeline uses homography world coords from calibration stub
- [ ] `cv-golden.yml` CI green

### Deferred until MSK / EKS deploy

- [ ] twin-api Helm chart on EKS
- [ ] spatial-query deployment
- [ ] twin-projector snapshot writer

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Migration fails on `PointZ` | Confirm PostGIS extension (`002_schemas.sql`) |
| Seed store conflict | Migrations idempotent; re-run safe |
| twin-api connection refused | Start port-forward; check DATABASE_URL |
| Outbox duplicate events | Expected in dev; Debezium dedupes at consumer |

---

## Related docs

- `docs/runbooks/phase-1-live-deployment.md`
- `docs/runbooks/phase-2-cloud-dev.md`
- `docs/runbooks/edge-feature-toggles.md`
- `docs/runbooks/credential-rotation.md`
