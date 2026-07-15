package health

import (
	"encoding/json"
	"fmt"
	"net/http"
	"sync"
	"time"
)

// Reporter tracks per-camera heartbeats for /health and /metrics.
type Reporter struct {
	mu         sync.RWMutex
	cameras    map[string]time.Time
	startedAt  time.Time
	dropped    uint64
}

func NewReporter() *Reporter {
	return &Reporter{
		cameras:   make(map[string]time.Time),
		startedAt: time.Now().UTC(),
	}
}

func (r *Reporter) Beat(cameraID string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.cameras[cameraID] = time.Now().UTC()
}

func (r *Reporter) SetDropped(total uint64) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.dropped = total
}

func (r *Reporter) Handler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})
	mux.HandleFunc("/readyz", func(w http.ResponseWriter, _ *http.Request) {
		r.mu.RLock()
		defer r.mu.RUnlock()
		if len(r.cameras) == 0 {
			http.Error(w, "no camera heartbeats", http.StatusServiceUnavailable)
			return
		}
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ready"))
	})
	mux.HandleFunc("/metrics", func(w http.ResponseWriter, _ *http.Request) {
		r.mu.RLock()
		defer r.mu.RUnlock()
		w.Header().Set("Content-Type", "text/plain; version=0.0.4")
		_, _ = w.Write([]byte("# HELP cv_dropped_frames_total Frames dropped by ring buffer\n"))
		_, _ = w.Write([]byte("# TYPE cv_dropped_frames_total counter\n"))
		_, _ = fmt.Fprintf(w, "cv_dropped_frames_total %d\n", r.dropped)
		for id, ts := range r.cameras {
			age := time.Since(ts).Seconds()
			_, _ = fmt.Fprintf(w, "camera_heartbeat_seconds{camera_id=%q} %.3f\n", id, age)
		}
	})
	mux.HandleFunc("/status", func(w http.ResponseWriter, _ *http.Request) {
		r.mu.RLock()
		defer r.mu.RUnlock()
		_ = json.NewEncoder(w).Encode(map[string]any{
			"uptime_sec": time.Since(r.startedAt).Seconds(),
			"cameras":    r.cameras,
			"dropped":    r.dropped,
		})
	})
	return mux
}
