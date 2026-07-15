# state-publisher

Go event publisher. **Cloud dev path** emits NDJSON `ProductPickedUp` events to stdout.

```powershell
cd services/edge/state-publisher
go run ./cmd/state-publisher
```

Kafka/Redis wiring deferred until MSK or in-cluster Kafka is enabled.

Tickets: RIP-2-080 (envelope wrapper).
