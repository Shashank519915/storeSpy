package publisher

import (
	"context"
	"encoding/json"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/Shashank519915/storeSpy/services/edge/state-publisher/internal/events"
)

// Outbox writes EventEnvelope rows to PostgreSQL outbox (RIP-1-030 / RIP-2-080).
type Outbox struct {
	conn *pgx.Conn
}

func NewOutbox(ctx context.Context, databaseURL string) (*Outbox, error) {
	conn, err := pgx.Connect(ctx, databaseURL)
	if err != nil {
		return nil, err
	}
	return &Outbox{conn: conn}, nil
}

func (o *Outbox) Close() { o.conn.Close(context.Background()) }

func (o *Outbox) Publish(ctx context.Context, env events.EventEnvelope) error {
	payload, err := json.Marshal(env.Payload)
	if err != nil {
		return err
	}
	meta, err := json.Marshal(map[string]string{
		"trace_id": env.TraceID,
		"span_id":  env.SpanID,
		"source":   "state-publisher",
	})
	if err != nil {
		return err
	}
	aggType := env.AggregateType
	if aggType == "" {
		aggType = "product_interaction"
	}
	aggID := env.AggregateID
	if aggID == "" {
		aggID = env.SessionID
	}
	_, err = o.conn.Exec(ctx, `
		INSERT INTO outbox (aggregate_type, aggregate_id, event_type, payload, metadata)
		VALUES ($1, $2, $3, $4, $5)
	`, aggType, aggID, env.EventType, payload, meta)
	return err
}

// PublishPickup builds and writes a pickup envelope.
func (o *Outbox) PublishPickup(ctx context.Context, storeID, sessionID, cameraID, trackID, sku, shelfID string, worldX, worldY, confidence float64) error {
	now := time.Now().UTC()
	env := events.EventEnvelope{
		EventID:       uuid.New().String(),
		TraceID:       uuid.New().String(),
		SpanID:        uuid.New().String()[:16],
		OccurredAt:    now,
		IngestedAt:    now,
		StoreID:       storeID,
		SessionID:     sessionID,
		SchemaVersion: "v1",
		EventType:     "vision.interaction.ProductPickedUp",
		AggregateType: "product_interaction",
		AggregateID:   trackID,
		Payload: events.ProductPickedUp{
			CameraID:   cameraID,
			TrackID:    trackID,
			ProductSKU: sku,
			ShelfID:    shelfID,
			WorldX:     worldX,
			WorldY:     worldY,
			Confidence: confidence,
		},
	}
	return o.Publish(ctx, env)
}
