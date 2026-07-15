package sources

import (
	"context"
	"testing"
	"time"
)

func TestVirtualCameraProducesFrames(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	cam := NewVirtualCamera("cam-test", 5, 32, 24)
	if err := cam.Open(ctx); err != nil {
		t.Fatalf("open: %v", err)
	}
	defer cam.Close()

	f, err := cam.Next(ctx)
	if err != nil {
		t.Fatalf("next: %v", err)
	}
	if len(f.Payload) != 32*24*3 {
		t.Fatalf("unexpected payload size %d", len(f.Payload))
	}
	if f.Metadata.CameraID != "cam-test" {
		t.Fatalf("camera id mismatch")
	}
}
