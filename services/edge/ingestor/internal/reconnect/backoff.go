package reconnect

import "time"

// Backoff implements 1s, 2s, 4s, 8s, 16s, 30s cap (RIP-2-003).
type Backoff struct {
	attempt int
}

func New() *Backoff { return &Backoff{} }

func (b *Backoff) Next() time.Duration {
	delays := []time.Duration{
		1 * time.Second,
		2 * time.Second,
		4 * time.Second,
		8 * time.Second,
		16 * time.Second,
		30 * time.Second,
	}
	if b.attempt >= len(delays) {
		return delays[len(delays)-1]
	}
	d := delays[b.attempt]
	b.attempt++
	return d
}

func (b *Backoff) Reset() { b.attempt = 0 }
