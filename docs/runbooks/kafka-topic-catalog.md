# Kafka Topic Catalog — RIP

**Tickets:** RIP-1-011, RIP-1-012, RIP-1-015

Authoritative topic definitions live in `infra/terraform/modules/msk-topics/`. The dev bootstrap copy is `infra/k8s/msk-topic-bootstrap/topics.json` — keep in sync when changing partitions.

## Domain topics

| Topic | Partition key | Dev partitions | Prod partitions |
|-------|---------------|----------------|-----------------|
| `vision.tracking.tracklet-updated` | `camera_id` | 12 | 96 |
| `vision.interaction.product-picked-up` | `session_id` | 6 | 24 |
| `vision.interaction.product-returned` | `session_id` | 6 | 24 |
| `vision.interaction.concealment-detected` | `session_id` | 6 | 24 |
| `retail.pos.transaction-event` | `session_id` | 6 | 24 |
| `twin.mutations.layout-changed` | `store_id` | 6 | 24 |
| `twin.mutations.camera-pitch-changed` | `store_id` | 6 | 24 |
| `twin.mutations.shelf-moved` | `store_id` | 6 | 24 |
| `lp.engine.hypothesis-updated` | `session_id` | 6 | 24 |
| `lp.engine.investigation-task-created` | `session_id` | 6 | 24 |

## Retry + DLQ topics (per consumer domain)

Each domain has `retry-1`, `retry-2`, `retry-3`, and `dlq` topics (3 partitions, RF=3):

- `vision.interaction.*`
- `vision.tracking.*`
- `twin.mutations.*`
- `retail.pos.*`
- `lp.engine.*`

## Cluster settings

| Setting | Dev value |
|---------|-----------|
| Replication factor | 3 |
| `min.insync.replicas` | 2 |
| Retention | 7 days (`log.retention.hours=168`) |
| `auto.create.topics.enable` | false |

## Provision topics (after MSK ACTIVE)

HCP Terraform creates the MSK cluster but cannot reach private brokers. Run from repo root:

```powershell
.\scripts\msk-provision-topics.ps1
```

Requires: EKS reachable, `rip-dev-msk-admin` IAM role (Terraform `msk-iam` module), MSK cluster status ACTIVE.

## MSK blocked on new AWS accounts

If Terraform apply fails with:

```
SubscriptionRequiredException: The AWS Access Key Id needs a subscription for the service
```

MSK (and GuardDuty) require a **payment method** on the AWS account before the service can be used.

1. AWS Console → **Billing and Cost Management** → add a payment method
2. In `infra/terraform/environments/dev/main.tf` set `enable_msk = true` (or add TFC workspace variable `enable_msk`)
3. Re-run apply in HCP Terraform — partial MSK resources from a failed run are cleaned up when `enable_msk=false`

Until MSK is available, Phase 1 can continue with **RDS + outbox + Debezium** (§1.4–1.5); Kafka topic bootstrap waits for MSK ACTIVE.

## Schema Registry

Internal topic: `_schemas` (created automatically by Schema Registry on first start).

Deploy Schema Registry after MSK:

```powershell
$bs = aws kafka get-bootstrap-brokers --region us-east-1 --cluster-arn <arn> --query BootstrapBrokerStringSaslIam --output text
helm repo add confluentinc https://confluentinc.github.io/cp-helm-charts/
helm upgrade --install schema-registry confluentinc/cp-schema-registry -n rip-system `
  -f infra/helm/charts/schema-registry/values.yaml `
  -f infra/helm/charts/schema-registry/values-dev.yaml `
  --set kafka.bootstrapServers=$bs
```

MSK IAM auth for Schema Registry requires a mounted `client.properties` secret — see `docs/runbooks/kafka-serde.md`.
