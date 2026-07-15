-- Kafka Engine ingest → vision_events MV
-- Ticket: RIP-1-053
-- Requires: Kafka bootstrap + Protobuf decode layer (Schema Registry) in production path.
-- Dev: substitute JSON or bare columns until Serde is wired (RIP-1-014).

CREATE TABLE IF NOT EXISTS analytics.vision_events_kafka
(
    raw String
)
ENGINE = Kafka
SETTINGS
    kafka_broker_list = 'REPLACE_KAFKA_BOOTSTRAP',
    kafka_topic_list = 'vision.interaction.product-picked-up,vision.interaction.product-returned,vision.interaction.concealment-detected',
    kafka_group_name = 'clickhouse-vision-ingest',
    kafka_format = 'JSONAsString',
    kafka_num_consumers = 1;

-- Placeholder MV — extend with JSONExtract columns when Serde path is live
CREATE MATERIALIZED VIEW IF NOT EXISTS analytics.vision_events_mv TO analytics.vision_events AS
SELECT
    toUUID(JSONExtractString(raw, 'event_id')) AS event_id,
    toUUID(JSONExtractString(raw, 'store_id')) AS store_id,
    toUUID(JSONExtractString(raw, 'session_id')) AS session_id,
    parseDateTime64BestEffort(JSONExtractString(raw, 'event_time')) AS event_time,
    JSONExtractString(raw, 'event_type') AS event_type,
    JSONExtractString(raw, 'camera_id') AS camera_id,
    toFloat32(JSONExtractFloat(raw, 'world_x')) AS world_x,
    toFloat32(JSONExtractFloat(raw, 'world_y')) AS world_y,
    toFloat32(JSONExtractFloat(raw, 'confidence')) AS confidence,
    raw AS payload,
    JSONExtractString(raw, 'trace_id') AS trace_id,
    now64(3) AS ingestion_time
FROM analytics.vision_events_kafka;
