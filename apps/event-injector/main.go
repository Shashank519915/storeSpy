// event-injector writes a transactional outbox row for Debezium CDC verification.
// Ticket: RIP-1-033
package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

func main() {
	var (
		dbURL         = envOr("DATABASE_URL", "postgresql://rip_admin@localhost:5432/rip?sslmode=disable")
		eventType     = flag.String("event-type", "twin.mutations.layout-changed", "outbox event_type (Kafka topic route)")
		aggregateType = flag.String("aggregate-type", "store_layout", "outbox aggregate_type")
		aggregateID   = flag.String("aggregate-id", "", "outbox aggregate_id (defaults to random UUID)")
		payload       = flag.String("payload", `{"version":1,"source":"event-injector"}`, "outbox payload bytes (UTF-8)")
		traceID       = flag.String("trace-id", "", "trace_id in metadata JSON (defaults to random UUID)")
	)
	flag.Parse()

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	aggID := *aggregateID
	if aggID == "" {
		aggID = uuid.New().String()
	}
	tid := *traceID
	if tid == "" {
		tid = uuid.New().String()
	}

	conn, err := pgx.Connect(ctx, dbURL)
	if err != nil {
		log.Fatalf("connect: %v", err)
	}
	defer conn.Close(ctx)

	metadata, err := json.Marshal(map[string]string{
		"trace_id": tid,
		"source":   "event-injector",
	})
	if err != nil {
		log.Fatalf("metadata: %v", err)
	}

	tx, err := conn.Begin(ctx)
	if err != nil {
		log.Fatalf("begin tx: %v", err)
	}
	defer tx.Rollback(ctx)

	var outboxID uuid.UUID
	err = tx.QueryRow(ctx, `
		INSERT INTO outbox (aggregate_type, aggregate_id, event_type, payload, metadata)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id
	`, *aggregateType, aggID, *eventType, []byte(*payload), metadata).Scan(&outboxID)
	if err != nil {
		log.Fatalf("insert outbox: %v", err)
	}

	if err := tx.Commit(ctx); err != nil {
		log.Fatalf("commit: %v", err)
	}

	fmt.Printf("outbox_id=%s event_type=%s aggregate_id=%s trace_id=%s\n",
		outboxID, *eventType, aggID, tid)
}

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
