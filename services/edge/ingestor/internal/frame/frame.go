package frame

import "time"

// Metadata travels with each decoded frame through the ring buffer and gRPC boundary.
type Metadata struct {
	CameraID      string
	CaptureTS     time.Time
	IngestTS      time.Time
	Sequence      uint64
	Width         int
	Height        int
	Source        string
	RTPNTPTimestamp int64
}

// Frame is a CPU-backed frame for cloud dev; GPU handles are added in the NVDEC path.
type Frame struct {
	Metadata Metadata
	// RGB24 row-major bytes (Width * Height * 3).
	Payload []byte
}

func (f Frame) BytesPerPixel() int { return 3 }

func (f Frame) ExpectedSize() int {
	return f.Metadata.Width * f.Metadata.Height * f.BytesPerPixel()
}
