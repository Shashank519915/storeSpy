package kafkaconsumer_test

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/Shashank519915/storeSpy/packages/go-common/kafkaconsumer"
)

func TestProcessIdempotent(t *testing.T) {
	store := kafkaconsumer.NewMemoryStore()
	cfg := kafkaconsumer.Config{IdempotencyTTL: time.Hour}
	calls := 0
	h := func(ctx context.Context, eventID string, payload []byte) error {
		calls++
		return nil
	}

	if err := kafkaconsumer.Process(context.Background(), store, cfg, "evt-1", []byte("{}"), h); err != nil {
		t.Fatal(err)
	}
	err := kafkaconsumer.Process(context.Background(), store, cfg, "evt-1", []byte("{}"), h)
	if !errors.Is(err, kafkaconsumer.ErrDuplicateEvent) {
		t.Fatalf("expected duplicate, got %v", err)
	}
	if calls != 1 {
		t.Fatalf("handler calls = %d, want 1", calls)
	}
}
