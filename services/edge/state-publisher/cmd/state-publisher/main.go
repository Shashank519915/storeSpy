package main

import (
	"flag"
	"log"
	"os"

	"github.com/Shashank519915/storeSpy/services/edge/state-publisher/internal/publisher"
)

func main() {
	var (
		storeID   = flag.String("store-id", "store-dev-01", "store identifier")
		sessionID = flag.String("session-id", "session-dev-01", "session partition key")
		cameraID  = flag.String("camera-id", "cam-virtual-01", "camera id")
		trackID   = flag.String("track-id", "track-001", "track id")
		sku       = flag.String("sku", "SKU-DEMO-001", "product sku")
		shelfID   = flag.String("shelf-id", "shelf-a1", "shelf id")
		worldX    = flag.Float64("world-x", 1.2, "world x meters")
		worldY    = flag.Float64("world-y", 3.4, "world y meters")
		conf      = flag.Float64("confidence", 0.91, "event confidence")
	)
	flag.Parse()

	pub := publisher.NewNDJSON(os.Stdout)
	if err := pub.PublishPickup(*storeID, *sessionID, *cameraID, *trackID, *sku, *shelfID, *worldX, *worldY, *conf); err != nil {
		log.Fatalf("publish: %v", err)
	}
}
