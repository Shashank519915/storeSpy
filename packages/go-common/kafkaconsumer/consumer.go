// Package kafkaconsumer provides idempotent Kafka consumption with retry/DLQ routing.
// Ticket: RIP-1-100 (scaffold — full implementation in later Phase 1 hardening)
package kafkaconsumer

import (
	"context"
	"errors"
	"fmt"
	"time"
)

// ErrDuplicateEvent is returned when idempotency key already exists.
var ErrDuplicateEvent = errors.New("duplicate event_id")

// Config holds consumer behavior knobs.
type Config struct {
	GroupID          string
	IdempotencyTTL   time.Duration
	RetryTopicSuffix string // e.g. ".retry-1"
	DLQTopicSuffix   string // e.g. ".dlq"
}

// Handler processes a single decoded message. Return nil to ACK.
type Handler func(ctx context.Context, eventID string, payload []byte) error

// IdempotencyStore abstracts SET NX semantics (Redis in production).
type IdempotencyStore interface {
	MarkIfNew(ctx context.Context, eventID string, ttl time.Duration) (bool, error)
}

// MemoryStore is a dev/test idempotency backend.
type MemoryStore struct {
	seen map[string]struct{}
}

func NewMemoryStore() *MemoryStore {
	return &MemoryStore{seen: make(map[string]struct{})}
}

func (m *MemoryStore) MarkIfNew(_ context.Context, eventID string, _ time.Duration) (bool, error) {
	if _, ok := m.seen[eventID]; ok {
		return false, nil
	}
	m.seen[eventID] = struct{}{}
	return true, nil
}

// Process applies idempotency then handler. Duplicate events are no-ops.
func Process(ctx context.Context, store IdempotencyStore, cfg Config, eventID string, payload []byte, h Handler) error {
	if eventID == "" {
		return fmt.Errorf("event_id required")
	}
	ttl := cfg.IdempotencyTTL
	if ttl == 0 {
		ttl = 24 * time.Hour
	}
	isNew, err := store.MarkIfNew(ctx, eventID, ttl)
	if err != nil {
		return err
	}
	if !isNew {
		return ErrDuplicateEvent
	}
	return h(ctx, eventID, payload)
}
