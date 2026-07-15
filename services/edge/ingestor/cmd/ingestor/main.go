package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os/signal"
	"syscall"
	"time"

	"github.com/Shashank519915/storeSpy/services/edge/ingestor/internal/buffer"
	"github.com/Shashank519915/storeSpy/services/edge/ingestor/internal/health"
	"github.com/Shashank519915/storeSpy/services/edge/ingestor/internal/sources"
)

func main() {
	var (
		sourceType = flag.String("source", "virtual", "input source: virtual|file")
		cameraID   = flag.String("camera-id", "cam-virtual-01", "camera identifier")
		filePath   = flag.String("file", "", "image file or directory (file source)")
		fps        = flag.Float64("fps", 10, "target frames per second")
		width      = flag.Int("width", 640, "virtual frame width")
		height     = flag.Int("height", 480, "virtual frame height")
		ringSize   = flag.Int("ring-size", 15, "ring buffer capacity (fps * latency budget)")
		httpAddr   = flag.String("http", ":8080", "health/metrics listen address")
		maxFrames  = flag.Int("max-frames", 0, "stop after N frames (0 = run until signal)")
	)
	flag.Parse()

	ctx, cancel := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer cancel()

	src, err := buildSource(*sourceType, *cameraID, *filePath, *fps, *width, *height)
	if err != nil {
		log.Fatalf("source: %v", err)
	}
	if err := src.Open(ctx); err != nil {
		log.Fatalf("open: %v", err)
	}
	defer src.Close()

	ring := buffer.NewRing(*ringSize)
	reporter := health.NewReporter()

	go func() {
		log.Printf("ingestor health on %s", *httpAddr)
		if err := http.ListenAndServe(*httpAddr, reporter.Handler()); err != nil && err != http.ErrServerClosed {
			log.Printf("health server: %v", err)
		}
	}()

	var produced uint64
	for {
		if *maxFrames > 0 && produced >= uint64(*maxFrames) {
			break
		}
		f, err := src.Next(ctx)
		if err != nil {
			if ctx.Err() != nil {
				break
			}
			log.Printf("next frame: %v", err)
			continue
		}
		ring.Push(f)
		reporter.Beat(f.Metadata.CameraID)
		reporter.SetDropped(ring.DroppedFrames())
		produced++
		if produced%uint64(max(1, int(*fps))) == 0 {
			log.Printf("camera=%s seq=%d ring_len=%d dropped=%d",
				f.Metadata.CameraID, f.Metadata.Sequence, ring.Len(), ring.DroppedFrames())
		}
	}
	log.Printf("ingestor stopped; produced=%d dropped=%d", produced, ring.DroppedFrames())
}

func buildSource(kind, cameraID, filePath string, fps float64, width, height int) (sources.InputSource, error) {
	switch kind {
	case "virtual":
		return sources.NewVirtualCamera(cameraID, fps, width, height), nil
	case "file":
		if filePath == "" {
			return nil, fmt.Errorf("file source requires -file")
		}
		return sources.NewFileSource(cameraID, filePath, fps)
	default:
		return nil, fmt.Errorf("unknown source %q", kind)
	}
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}
