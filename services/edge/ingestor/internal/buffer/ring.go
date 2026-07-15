package buffer

import (
	"sync/atomic"

	"github.com/Shashank519915/storeSpy/services/edge/ingestor/internal/frame"
)

// Ring is a fixed-size latest-frame buffer with drop-oldest policy (RIP-2-004/005).
type Ring struct {
	slots            []frame.Frame
	capacity         int
	head             atomic.Uint64
	tail             atomic.Uint64
	droppedFrames    atomic.Uint64
}

func NewRing(capacity int) *Ring {
	if capacity < 1 {
		capacity = 15
	}
	return &Ring{
		slots:    make([]frame.Frame, capacity),
		capacity: capacity,
	}
}

func (r *Ring) Capacity() int { return r.capacity }

func (r *Ring) DroppedFrames() uint64 { return r.droppedFrames.Load() }

func (r *Ring) Push(f frame.Frame) {
	head := r.head.Add(1)
	tail := r.tail.Load()
	if head-tail > uint64(r.capacity) {
		r.tail.Store(head - uint64(r.capacity))
		r.droppedFrames.Add(1)
	}
	r.slots[(head-1)%uint64(r.capacity)] = f
}

func (r *Ring) Pop() (frame.Frame, bool) {
	tail := r.tail.Load()
	head := r.head.Load()
	if tail >= head {
		return frame.Frame{}, false
	}
	next := tail + 1
	r.tail.Store(next)
	return r.slots[(next-1)%uint64(r.capacity)], true
}

func (r *Ring) Len() int {
	head := r.head.Load()
	tail := r.tail.Load()
	if head < tail {
		return 0
	}
	n := int(head - tail)
	if n > r.capacity {
		return r.capacity
	}
	return n
}
