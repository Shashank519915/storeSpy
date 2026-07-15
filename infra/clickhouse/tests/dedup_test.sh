#!/usr/bin/env bash
# ClickHouse ReplacingMergeTree dedup smoke test — Ticket: RIP-1-055
set -euo pipefail

CH_HOST="${CH_HOST:-clickhouse.rip-system.svc.cluster.local}"
CH_PORT="${CH_PORT:-9000}"
EVENT_ID="${EVENT_ID:-$(uuidgen)}"

clickhouse-client --host "$CH_HOST" --port "$CH_PORT" --query "
INSERT INTO analytics.vision_events (event_id, store_id, session_id, event_time, event_type, camera_id, world_x, world_y, confidence, payload, trace_id, ingestion_time)
VALUES
('$EVENT_ID', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', now(), 'test.dedup', 'cam-1', 1.0, 2.0, 0.9, '{}', 'trace-1', now64(3)),
('$EVENT_ID', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', now(), 'test.dedup', 'cam-1', 1.0, 2.0, 0.9, '{}', 'trace-1', now64(3) + 1);
"

COUNT=$(clickhouse-client --host "$CH_HOST" --port "$CH_PORT" --query "
SELECT count() FROM analytics.vision_events FINAL WHERE event_id = '$EVENT_ID';
")

if [[ "$COUNT" != "1" ]]; then
  echo "FAIL: expected 1 row for event_id=$EVENT_ID, got $COUNT"
  exit 1
fi

echo "PASS: ReplacingMergeTree dedup for event_id=$EVENT_ID"
