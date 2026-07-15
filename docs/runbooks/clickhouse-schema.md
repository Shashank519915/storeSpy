# ClickHouse Schema — RIP Analytics

**DDL:** `infra/clickhouse/schemas/`  
**Deploy:** §1.6 — after Kafka ingest path is live (Path B or C)

## Databases and tables

| Object | Engine | Purpose |
|--------|--------|---------|
| `analytics.vision_events` | ReplacingMergeTree(`ingestion_time`) | Idempotent vision event store |
| `analytics.vision_events_kafka` | Kafka | Ingest from `vision.interaction.*` topics |
| `analytics.vision_events_mv` | Materialized View | Kafka → `vision_events` |
| `analytics.heatmap_grid` | SummingMergeTree | 0.5m cell hourly aggregates |

## Apply order

1. `vision_events.sql` — base table + TTL (90d hot)
2. `kafka_ingest.sql` — replace `REPLACE_KAFKA_BOOTSTRAP` with cluster bootstrap
3. `heatmap_mv.sql` — depends on `vision_events`

## Dedup verification

```bash
CH_HOST=clickhouse.rip-system.svc.cluster.local ./infra/clickhouse/tests/dedup_test.sh
```

Pass: duplicate `event_id` inserts collapse to **1 row** with `FINAL`.

## Serde note

`kafka_ingest.sql` uses JSON placeholder columns until Protobuf + Schema Registry Serde is wired (RIP-1-014). Swap `kafka_format` and MV extraction when registry is live.
