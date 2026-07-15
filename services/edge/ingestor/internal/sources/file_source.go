package sources

import (
	"context"
	"fmt"
	"image"
	_ "image/jpeg"
	_ "image/png"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/Shashank519915/storeSpy/services/edge/ingestor/internal/frame"
)

// FileSource replays still frames from a directory or single image on a timer.
type FileSource struct {
	cameraID string
	fps      float64
	paths    []string
	index    int
	seq      uint64
	ticker   *time.Ticker
}

func NewFileSource(cameraID, path string, fps float64) (*FileSource, error) {
	paths, err := resolveFramePaths(path)
	if err != nil {
		return nil, err
	}
	if fps <= 0 {
		fps = 10
	}
	return &FileSource{cameraID: cameraID, fps: fps, paths: paths}, nil
}

func resolveFramePaths(path string) ([]string, error) {
	info, err := os.Stat(path)
	if err != nil {
		return nil, err
	}
	if !info.IsDir() {
		return []string{path}, nil
	}
	entries, err := os.ReadDir(path)
	if err != nil {
		return nil, err
	}
	var paths []string
	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		ext := strings.ToLower(filepath.Ext(e.Name()))
		if ext == ".jpg" || ext == ".jpeg" || ext == ".png" {
			paths = append(paths, filepath.Join(path, e.Name()))
		}
	}
	sort.Strings(paths)
	if len(paths) == 0 {
		return nil, fmt.Errorf("no image frames in %s", path)
	}
	return paths, nil
}

func (f *FileSource) ID() string { return f.cameraID }

func (f *FileSource) Open(ctx context.Context) error {
	interval := time.Duration(float64(time.Second) / f.fps)
	f.ticker = time.NewTicker(interval)
	select {
	case <-ctx.Done():
		return ctx.Err()
	case <-f.ticker.C:
		return nil
	}
}

func (f *FileSource) Next(ctx context.Context) (frame.Frame, error) {
	if f.ticker == nil {
		return frame.Frame{}, fmt.Errorf("file source %s not open", f.cameraID)
	}
	select {
	case <-ctx.Done():
		return frame.Frame{}, ctx.Err()
	case t := <-f.ticker.C:
		path := f.paths[f.index%len(f.paths)]
		f.index++
		f.seq++
		payload, w, h, err := loadRGB(path)
		if err != nil {
			return frame.Frame{}, err
		}
		return frame.Frame{
			Metadata: frame.Metadata{
				CameraID:  f.cameraID,
				CaptureTS: t,
				IngestTS:  time.Now().UTC(),
				Sequence:  f.seq,
				Width:     w,
				Height:    h,
				Source:    "file",
			},
			Payload: payload,
		}, nil
	}
}

func (f *FileSource) Close() error {
	if f.ticker != nil {
		f.ticker.Stop()
	}
	return nil
}

func loadRGB(path string) ([]byte, int, int, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, 0, 0, err
	}
	defer file.Close()
	img, _, err := image.Decode(file)
	if err != nil {
		return nil, 0, 0, err
	}
	bounds := img.Bounds()
	w := bounds.Dx()
	h := bounds.Dy()
	out := make([]byte, w*h*3)
	for y := bounds.Min.Y; y < bounds.Max.Y; y++ {
		for x := bounds.Min.X; x < bounds.Max.X; x++ {
			r, g, b, _ := img.At(x, y).RGBA()
			i := ((y-bounds.Min.Y)*w + (x - bounds.Min.X)) * 3
			out[i] = byte(r >> 8)
			out[i+1] = byte(g >> 8)
			out[i+2] = byte(b >> 8)
		}
	}
	return out, w, h, nil
}
