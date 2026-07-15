package buffer

import (
	"testing"

	"github.com/Shashank519915/storeSpy/services/edge/ingestor/internal/frame"
)

func TestRingDropOldest(t *testing.T) {
	r := NewRing(2)
	r.Push(frameWithSeq(1))
	r.Push(frameWithSeq(2))
	r.Push(frameWithSeq(3))

	if r.DroppedFrames() != 1 {
		t.Fatalf("expected 1 drop, got %d", r.DroppedFrames())
	}
	if r.Len() != 2 {
		t.Fatalf("expected len 2, got %d", r.Len())
	}
	f1, ok := r.Pop()
	if !ok || f1.Metadata.Sequence != 2 {
		t.Fatalf("expected seq 2, got %+v ok=%v", f1.Metadata, ok)
	}
	f2, ok := r.Pop()
	if !ok || f2.Metadata.Sequence != 3 {
		t.Fatalf("expected seq 3, got %+v ok=%v", f2.Metadata, ok)
	}
}

func frameWithSeq(seq uint64) frame.Frame {
	return frame.Frame{Metadata: frame.Metadata{Sequence: seq}}
}
