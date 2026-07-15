package sources

import (
	"context"

	"github.com/Shashank519915/storeSpy/services/edge/ingestor/internal/frame"
)

// InputSource decodes frames from RTSP, files, or synthetic virtual cameras.
type InputSource interface {
	ID() string
	Open(ctx context.Context) error
	Next(ctx context.Context) (frame.Frame, error)
	Close() error
}
