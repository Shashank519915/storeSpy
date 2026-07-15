package publisher

import (
	"encoding/json"
	"io"
	"time"

	"github.com/google/uuid"

	"github.com/Shashank519915/storeSpy/services/edge/state-publisher/internal/events"
)

// NDJSON writes one EventEnvelope per line for local pipeline testing without Kafka/Redis.
type NDJSON struct {
	w io.Writer
}

func NewNDJSON(w io.Writer) *NDJSON { return &NDJSON{w: w} }

func (p *NDJSON) PublishPickup(storeID, sessionID, cameraID, trackID, sku, shelfID string, worldX, worldY, confidence float64) error {
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
	b, err := json.Marshal(env)
	if err != nil {
		return err
	}
	_, err = p.w.Write(append(b, '\n'))
	return err
}
