package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"github.com/Shashank519915/storeSpy/services/edge/ingestor/internal/buffer"
	"github.com/Shashank519915/storeSpy/services/edge/ingestor/internal/sources"
)

// FrameTick is NDJSON emitted to cv-orchestrator pipeline runner.
type FrameTick struct {
	CameraID string  `json:"camera_id"`
	Sequence uint64  `json:"sequence"`
	Width    int     `json:"width"`
	Height   int     `json:"height"`
	Source   string  `json:"source"`
	FPS      float64 `json:"fps"`
}

func main() {
	var (
		cameraID  = flag.String("camera-id", "cam-virtual-01", "camera id")
		fps       = flag.Float64("fps", 10, "virtual camera fps")
		width     = flag.Int("width", 640, "frame width")
		height    = flag.Int("height", 480, "frame height")
		maxFrames = flag.Int("max-frames", 30, "frames to emit")
		ringSize  = flag.Int("ring-size", 15, "ring buffer capacity")
	)
	flag.Parse()

	ctx, cancel := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer cancel()

	cam := sources.NewVirtualCamera(*cameraID, *fps, *width, *height)
	if err := cam.Open(ctx); err != nil {
		fmt.Fprintf(os.Stderr, "open camera: %v\n", err)
		os.Exit(1)
	}
	defer cam.Close()

	ring := buffer.NewRing(*ringSize)
	enc := json.NewEncoder(os.Stdout)

	var produced int
	for produced < *maxFrames {
		f, err := cam.Next(ctx)
		if err != nil {
			if ctx.Err() != nil {
				break
			}
			fmt.Fprintf(os.Stderr, "frame: %v\n", err)
			break
		}
		ring.Push(f)
		produced++
		tick := FrameTick{
			CameraID: f.Metadata.CameraID,
			Sequence: f.Metadata.Sequence,
			Width:    f.Metadata.Width,
			Height:   f.Metadata.Height,
			Source:   f.Metadata.Source,
			FPS:      *fps,
		}
		if err := enc.Encode(tick); err != nil {
			fmt.Fprintf(os.Stderr, "encode: %v\n", err)
			os.Exit(1)
		}
	}
	fmt.Fprintf(os.Stdout, "# pipeline: produced=%d dropped=%d\n", produced, ring.DroppedFrames())
}
