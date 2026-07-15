# event-injector

Go QA synthetic event injector — writes a transactional **outbox** row for Debezium CDC verification (RIP-1-033).

## Usage

```powershell
# Against PgBouncer (in-cluster) or RDS via port-forward
$env:DATABASE_URL = "postgresql://rip_admin:<password>@localhost:5432/rip?sslmode=require"
go run . -event-type twin.mutations.layout-changed -aggregate-id <store-uuid>
```

## Flags

| Flag | Default | Description |
|------|---------|-------------|
| `-event-type` | `twin.mutations.layout-changed` | Routed Kafka topic via Debezium EventRouter |
| `-aggregate-type` | `store_layout` | Outbox aggregate type |
| `-aggregate-id` | random UUID | Business key |
| `-payload` | minimal JSON | Raw bytes stored in `outbox.payload` |
| `-trace-id` | random UUID | Stored in `outbox.metadata` |

## Verify Kafka (after Debezium connector is RUNNING)

```powershell
kubectl port-forward -n rip-system svc/kafka-dev 9092:9092
# consume from topic matching event_type
```

See `docs/runbooks/phase-1-live-deployment.md` §7.
