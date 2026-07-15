package sources

import (
	"context"
	"fmt"
	"time"

	"github.com/Shashank519915/storeSpy/services/edge/ingestor/internal/frame"
)

// VirtualCamera synthesizes frames at a target FPS for cloud dev without RTSP or GPU.
type VirtualCamera struct {
	cameraID string
	fps      float64
	width    int
	height   int
	seq      uint64
	ticker   *time.Ticker
}

func NewVirtualCamera(cameraID string, fps float64, width, height int) *VirtualCamera {
	if fps <= 0 {
		fps = 10
	}
	if width <= 0 {
		width = 640
	}
	if height <= 0 {
		height = 480
	}
	return &VirtualCamera{
		cameraID: cameraID,
		fps:      fps,
		width:    width,
		height:   height,
	}
}

func (v *VirtualCamera) ID() string { return v.cameraID }

func (v *VirtualCamera) Open(ctx context.Context) error {
	interval := time.Duration(float64(time.Second) / v.fps)
	v.ticker = time.NewTicker(interval)
	select {
	case <-ctx.Done():
		return ctx.Err()
	case <-v.ticker.C:
		return nil
	}
}

func (v *VirtualCamera) Next(ctx context.Context) (frame.Frame, error) {
	if v.ticker == nil {
		return frame.Frame{}, fmt.Errorf("virtual camera %s not open", v.cameraID)
	}
	select {
	case <-ctx.Done():
		return frame.Frame{}, ctx.Err()
	case t := <-v.ticker.C:
		v.seq++
		payload := synthesizeRGB(v.width, v.height, v.seq)
		return frame.Frame{
			Metadata: frame.Metadata{
				CameraID:  v.cameraID,
				CaptureTS: t,
				IngestTS:  time.Now().UTC(),
				Sequence:  v.seq,
				Width:     v.width,
				Height:    v.height,
				Source:    "virtual",
			},
			Payload: payload,
		}, nil
	}
}

func (v *VirtualCamera) Close() error {
	if v.ticker != nil {
		v.ticker.Stop()
	}
	return nil
}

// synthesizeRGB produces a deterministic gradient pattern for golden-test diffs.
func synthesizeRGB(width, height int, seq uint64) []byte {
	out := make([]byte, width*height*3)
	for y := 0; y < height; y++ {
		for x := 0; x < width; x++ {
			i := (y*width + x) * 3
			out[i] = byte((x + int(seq)) % 256)
			out[i+1] = byte((y + int(seq*3)) % 256)
			out[i+2] = byte((x + y + int(seq*7)) % 256)
		}
	}
	return out
}
