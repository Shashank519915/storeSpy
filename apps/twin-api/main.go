package main

import (
	"context"
	"encoding/json"
	"flag"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

func main() {
	addr := flag.String("addr", ":8081", "listen address")
	dbURL := flag.String("database-url", envOr("DATABASE_URL", ""), "PostgreSQL URL")
	flag.Parse()

	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})

	mux.HandleFunc("POST /api/twin/{storeID}/mutations/shelf-moved", func(w http.ResponseWriter, r *http.Request) {
		if *dbURL == "" {
			http.Error(w, "DATABASE_URL not configured", http.StatusServiceUnavailable)
			return
		}
		storeID := r.PathValue("storeID")
		var body struct {
			ShelfID    string  `json:"shelf_id"`
			WorldX     float64 `json:"world_x"`
			WorldY     float64 `json:"world_y"`
			TwinVersion int    `json:"twin_version"`
		}
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		if body.ShelfID == "" {
			http.Error(w, "shelf_id required", http.StatusBadRequest)
			return
		}

		ctx, cancel := context.WithTimeout(r.Context(), 10*time.Second)
		defer cancel()

		payload, _ := json.Marshal(body)
		meta, _ := json.Marshal(map[string]string{
			"trace_id": uuid.New().String(),
			"source":   "twin-api",
			"store_id": storeID,
		})

		conn, err := pgx.Connect(ctx, *dbURL)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		defer conn.Close(ctx)

		var outboxID uuid.UUID
		err = conn.QueryRow(ctx, `
			INSERT INTO outbox (aggregate_type, aggregate_id, event_type, payload, metadata)
			VALUES ($1, $2, $3, $4, $5)
			RETURNING id
		`, "twin_layout", body.ShelfID, "twin.mutations.shelf-moved", payload, meta).Scan(&outboxID)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]any{
			"outbox_id":  outboxID,
			"event_type": "twin.mutations.shelf-moved",
			"store_id":   storeID,
		})
	})

	log.Printf("twin-api listening on %s", *addr)
	log.Fatal(http.ListenAndServe(*addr, mux))
}

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
