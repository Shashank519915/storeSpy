# Redis Key Schema — RIP Cloud
# Tickets: RIP-1-081, RIP-1-082

Key patterns for idempotency and session snapshot prep (Phase 4).

## Idempotency (consumer dedupe)

| Key | Type | TTL | Writer | Reader |
|-----|------|-----|--------|--------|
| `idempotency:{event_id}` | STRING (SET NX) | 86400s | All Kafka consumers | Same consumer on retry |

**Semantics:** `SET idempotency:{event_id} 1 NX EX 86400` — if key exists, skip processing and ACK offset.

**Value:** `1` (presence only). Optional metadata (`processed_at`) only in debug builds.

## Session snapshot (Phase 4 prep)

| Key | Type | TTL | Fields |
|-----|------|-----|--------|
| `session:{store_id}:{session_id}` | HASH | none (explicit delete) | `last_event_time`, `world_x`, `world_y`, `tracklet_count`, `updated_at` |

**Writer:** `session-snapshot-service` (Phase 4)  
**Reader:** LP engine, portal live map

## Edge buffer (Phase 1 §1.3)

| Key | Type | Notes |
|-----|------|-------|
| `edge:events:{store_id}` | STREAM | Redis Streams; MAXLEN ~ 2M approximate |
| `edge:forwarder:last_id:{store_id}` | HASH | Bridge idempotency checkpoint |

## ACL (RIP-1-083)

Per-service Redis ACL users with Vault-dynamic passwords — configure when Redis Cluster (§1.9) is deployed.

| Service | Allowed commands | Key pattern |
|---------|------------------|-------------|
| `vision-consumer` | `+get +set +setnx +expire` | `idempotency:*` |
| `session-snapshot` | `+hset +hgetall +expire` | `session:*` |
| `edge-bridge` | `+xreadgroup +xack +xlen` | `edge:*` |
