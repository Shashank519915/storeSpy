# Kafka Protobuf Serde — RIP

**Ticket:** RIP-1-014

## Wire format

- **Encoding:** Confluent Schema Registry wire format (magic byte `0x00` + 4-byte schema ID + Protobuf payload).
- **Compatibility:** `BACKWARD_TRANSITIVE` — consumers must tolerate new optional fields; producers must not break existing consumers.
- **Envelope:** Every domain message embeds `rip.common.v1.EventEnvelope` as field `1`.

## Topic naming

| Domain | Topic pattern | Partition key |
|--------|---------------|---------------|
| Vision interaction | `vision.interaction.product-picked-up` | `session_id` |
| Vision tracking | `vision.tracking.tracklet-updated` | `camera_id` |
| Twin mutations | `twin.mutations.layout-changed` | `store_id` |
| POS | `retail.pos.transaction-event` | `session_id` |
| LP engine | `lp.engine.investigation-task-created` | `session_id` |

## Producer checklist

1. Generate `event_id` as UUIDv7.
2. Propagate W3C `trace_id` / `span_id` from OTel context into envelope.
3. Set `schema_version` to the buf module tag or `rip.common.v1` minor version.
4. Pack payload into `EventEnvelope.payload` via `google.protobuf.Any` when using the wrapper pattern.

## Consumer checklist

1. Deserialize via Schema Registry; validate schema ID.
2. Check Redis `idempotency:{event_id}` SET NX before side effects.
3. On failure: publish to `*.retry-N` then `*.dlq` per consumer library (`packages/go-common/kafkaconsumer`).

## Dev without MSK

Use `apps/event-injector` outbox path for local verification before MSK is provisioned (RIP-1-033).
