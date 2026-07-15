package main

import (
	"bufio"
	"context"
	"encoding/json"
	"flag"
	"log"
	"os"
	"strings"
	"time"

	"github.com/Shashank519915/storeSpy/services/edge/state-publisher/internal/events"
	"github.com/Shashank519915/storeSpy/services/edge/state-publisher/internal/publisher"
)

func main() {
	var (
		sink        = flag.String("sink", "stdout", "stdout | outbox")
		databaseURL = flag.String("database-url", envOr("DATABASE_URL", ""), "PostgreSQL URL for outbox sink")
		fromStdin   = flag.Bool("stdin", false, "read EventEnvelope JSON lines from stdin")
		storeID     = flag.String("store-id", "store-dev-01", "store identifier")
		sessionID   = flag.String("session-id", "session-dev-01", "session partition key")
		cameraID    = flag.String("camera-id", "cam-virtual-01", "camera id")
		trackID     = flag.String("track-id", "track-001", "track id")
		sku         = flag.String("sku", "SKU-DEMO-001", "product sku")
		shelfID     = flag.String("shelf-id", "shelf-a1", "shelf id")
		worldX      = flag.Float64("world-x", 1.2, "world x meters")
		worldY      = flag.Float64("world-y", 3.4, "world y meters")
		conf        = flag.Float64("confidence", 0.91, "event confidence")
	)
	flag.Parse()

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if *fromStdin {
		if err := publishStdin(ctx, *sink, *databaseURL, os.Stdin, os.Stdout); err != nil {
			log.Fatalf("stdin publish: %v", err)
		}
		return
	}

	if *sink == "outbox" {
		if *databaseURL == "" {
			log.Fatal("outbox sink requires -database-url or DATABASE_URL")
		}
		ob, err := publisher.NewOutbox(ctx, *databaseURL)
		if err != nil {
			log.Fatalf("outbox: %v", err)
		}
		defer ob.Close()
		if err := ob.PublishPickup(ctx, *storeID, *sessionID, *cameraID, *trackID, *sku, *shelfID, *worldX, *worldY, *conf); err != nil {
			log.Fatalf("publish: %v", err)
		}
		log.Printf("outbox: wrote event_type=vision.interaction.ProductPickedUp track=%s", *trackID)
		return
	}

	pub := publisher.NewNDJSON(os.Stdout)
	if err := pub.PublishPickup(*storeID, *sessionID, *cameraID, *trackID, *sku, *shelfID, *worldX, *worldY, *conf); err != nil {
		log.Fatalf("publish: %v", err)
	}
}

func publishStdin(ctx context.Context, sink, databaseURL string, r *os.File, w *os.File) error {
	scanner := bufio.NewScanner(r)
	scanner.Buffer(make([]byte, 0, 64*1024), 1024*1024)

	var ob *publisher.Outbox
	var nd *publisher.NDJSON
	if sink == "outbox" {
		if databaseURL == "" {
			return errString("outbox sink requires DATABASE_URL")
		}
		var err error
		ob, err = publisher.NewOutbox(ctx, databaseURL)
		if err != nil {
			return err
		}
		defer ob.Close()
	} else {
		nd = publisher.NewNDJSON(w)
	}

	count := 0
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}
		var raw map[string]any
		if err := json.Unmarshal([]byte(line), &raw); err != nil {
			return err
		}
		env, err := envelopeFromMap(raw)
		if err != nil {
			return err
		}
		if ob != nil {
			if err := ob.Publish(ctx, env); err != nil {
				return err
			}
			log.Printf("outbox: wrote event_id=%s event_type=%s", env.EventID, env.EventType)
		} else if nd != nil {
			b, _ := json.Marshal(env)
			if _, err := w.Write(append(b, '\n')); err != nil {
				return err
			}
		}
		count++
	}
	if err := scanner.Err(); err != nil {
		return err
	}
	if count == 0 {
		log.Print("stdin: no events received")
	}
	return nil
}

func envelopeFromMap(raw map[string]any) (events.EventEnvelope, error) {
	b, err := json.Marshal(raw)
	if err != nil {
		return events.EventEnvelope{}, err
	}
	var env events.EventEnvelope
	if err := json.Unmarshal(b, &env); err != nil {
		return events.EventEnvelope{}, err
	}
	if env.AggregateType == "" {
		if v, ok := raw["aggregate_type"].(string); ok {
			env.AggregateType = v
		}
	}
	if env.AggregateID == "" {
		if v, ok := raw["aggregate_id"].(string); ok {
			env.AggregateID = v
		}
	}
	return env, nil
}

type errString string

func (e errString) Error() string { return string(e) }

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
