-- Heatmap grid aggregate — 0.5m cells hourly
-- Ticket: RIP-1-054

CREATE TABLE IF NOT EXISTS analytics.heatmap_grid
(
    store_id    UUID,
    cell_x      Int32,
    cell_y      Int32,
    hour        DateTime('UTC'),
    event_count UInt64,
    updated_at  DateTime64(3, 'UTC') DEFAULT now64(3)
)
ENGINE = SummingMergeTree
PARTITION BY toYYYYMM(hour)
ORDER BY (store_id, hour, cell_x, cell_y);

CREATE MATERIALIZED VIEW IF NOT EXISTS analytics.heatmap_grid_mv TO analytics.heatmap_grid AS
SELECT
    store_id,
    toInt32(floor(world_x / 0.5)) AS cell_x,
    toInt32(floor(world_y / 0.5)) AS cell_y,
    toStartOfHour(event_time) AS hour,
    count() AS event_count,
    max(ingestion_time) AS updated_at
FROM analytics.vision_events
WHERE event_type IN (
    'vision.interaction.product-picked-up',
    'vision.interaction.session-moved'
)
GROUP BY store_id, cell_x, cell_y, hour;
