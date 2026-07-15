package events

import "time"

// EventEnvelope mirrors rip.common.v1.EventEnvelope for cloud dev NDJSON output.
type EventEnvelope struct {
	EventID       string    `json:"event_id"`
	TraceID       string    `json:"trace_id"`
	SpanID        string    `json:"span_id"`
	OccurredAt    time.Time `json:"occurred_at"`
	IngestedAt    time.Time `json:"ingested_at"`
	StoreID       string    `json:"store_id"`
	SessionID     string    `json:"session_id"`
	SchemaVersion string    `json:"schema_version"`
	EventType     string    `json:"event_type"`
	AggregateType string    `json:"aggregate_type,omitempty"`
	AggregateID   string    `json:"aggregate_id,omitempty"`
	Payload       any       `json:"payload"`
}

type ProductPickedUp struct {
	CameraID       string  `json:"camera_id"`
	TrackID        string  `json:"track_id"`
	ProductSKU     string  `json:"product_sku"`
	ShelfID        string  `json:"shelf_id"`
	WorldX         float64 `json:"world_x"`
	WorldY         float64 `json:"world_y"`
	Confidence     float64 `json:"confidence"`
}
