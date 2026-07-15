# Feature Toggles — rip-dev

**Deployment guide:** `docs/runbooks/phase-1-live-deployment.md` (step-by-step paths A/B/C)

Single place to enable/disable paid or subscription-gated AWS services without ripping out code.

## Terraform toggles (HCP Terraform workspace `rip-dev`)

Set in **Variables** (Terraform category, not Environment) or edit defaults in `infra/terraform/environments/dev/feature-toggles.tf`:

| Variable | Default (dev) | What it controls |
|----------|---------------|------------------|
| `enable_msk` | `false` | AWS MSK cluster + `msk-iam` IRSA roles |
| `enable_rds` | `true` | RDS PostgreSQL 16 (`db.t4g.micro`, single-AZ) |

After changing a toggle: push to `main` (or run plan in TFC) → apply.

### Enable MSK later

1. Confirm MSK subscription works (no `SubscriptionRequiredException` on a test apply)
2. Set `enable_msk = true` in TFC or `feature-toggles.tf`
3. Apply (~20–30 min)
4. Run `.\scripts\msk-provision-topics.ps1`
5. Set `enable_incluster_kafka: false` in `infra/config/dev/feature-flags.yaml` (MSK replaces in-cluster)
6. Redeploy Schema Registry / Debezium if enabled

## Runtime / Helm toggles

Edit `infra/config/dev/feature-flags.yaml` (mirrors Terraform where noted):

| Flag | Default | Requires | Helm / script |
|------|---------|----------|---------------|
| `enable_incluster_kafka` | `false` | EKS pod capacity | `infra/helm/charts/kafka-dev/` |
| `enable_schema_registry` | `false` | Kafka bootstrap | `infra/helm/charts/schema-registry/` |
| `enable_debezium` | `false` | Kafka + RDS | `infra/helm/charts/kafka-connect/` |

Deploy platform components:

```powershell
.\scripts\phase1-deploy-platform.ps1
```

Script reads Terraform outputs when available, else `feature-flags.yaml`.

## Kafka bootstrap resolution

| MSK | In-cluster | Bootstrap servers | Auth |
|-----|------------|-------------------|------|
| off | off | *(none — outbox/RDS only)* | — |
| off | on | `kafka-dev.rip-system.svc.cluster.local:9092` | plaintext |
| on | off | MSK `bootstrap_brokers_sasl_iam` | AWS_MSK_IAM |
| on | on | MSK wins | AWS_MSK_IAM |

## Outputs

After apply, check TFC outputs:

- `feature_flags` — current toggle state
- `kafka_bootstrap_servers` — sensitive when MSK on
- `rds_endpoint` — when `enable_rds=true`
