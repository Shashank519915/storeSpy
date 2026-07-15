# twin-api

Go Digital Twin mutation API. **Cloud dev path** writes mutation commands to the transactional `outbox` table (Debezium -> Kafka when MSK is enabled).

## Run locally

```powershell
# Requires PgBouncer port-forward + DATABASE_URL (see phase-3-live-deployment.md)
cd apps/twin-api
go run . -addr :8081
```

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/healthz` | Health check |
| POST | `/api/twin/{storeID}/mutations/shelf-moved` | Writes `twin.mutations.shelf-moved` to outbox |

Tickets: RIP-3-010 (scaffold), RIP-3-011 (shelf-moved command).
