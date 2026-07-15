-- ClickHouse analytics.vision_events — ReplacingMergeTree idempotency
-- Ticket: RIP-1-051, RIP-1-052
-- Apply when ClickHouse cluster is live (§1.6)

CREATE DATABASE IF NOT EXISTS analytics;

CREATE TABLE IF NOT EXISTS analytics.vision_events
(
    event_id        UUID,
    store_id        UUID,
    session_id      UUID,
    event_time      DateTime64(3, 'UTC'),
    event_date      Date MATERIALIZED toDate(event_time),
    event_type      LowCardinality(String),
    camera_id       String,
    world_x         Float32,
    world_y         Float32,
    confidence      Float32,
    payload         String,
    trace_id        String,
    ingestion_time  DateTime64(3, 'UTC') DEFAULT now64(3)
)
ENGINE = ReplacingMergeTree(ingestion_time)
PARTITION BY toYYYYMM(event_date)
ORDER BY (store_id, session_id, event_time, event_type, event_id)
TTL event_date + INTERVAL 90 DAY
SETTINGS index_granularity = 8192;
