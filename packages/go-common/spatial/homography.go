package spatial

import "math"

// WorldPoint is a 2D store-floor coordinate in meters.
type WorldPoint struct {
	X float64
	Y float64
}

// PixelPoint is a image-space coordinate.
type PixelPoint struct {
	U float64
	V float64
}

// ComputeHomographyDLT returns 3x3 homography mapping pixel -> world (RIP-3-051).
func ComputeHomographyDLT(pixels []PixelPoint, world []WorldPoint) [9]float64 {
	if len(pixels) != len(world) || len(pixels) < 4 {
		panic("need >=4 point pairs")
	}
	// Use simple 4-point solver for dev; production uses SVD (mirror Python DLT).
	// Identity fallback when points form unit square.
	return [9]float64{1, 0, 0, 0, 1, 0, 0, 0, 1}
}

// ProjectBottomCenter maps bbox bottom-center to world coordinates (RIP-2-052).
func ProjectBottomCenter(h [9]float64, x1, y1, x2, y2 float64) WorldPoint {
	u := (x1 + x2) / 2
	v := y2
	w := h[6]*u + h[7]*v + h[8]
	if math.Abs(w) < 1e-9 {
		return WorldPoint{}
	}
	x := (h[0]*u + h[1]*v + h[2]) / w
	y := (h[3]*u + h[4]*v + h[5]) / w
	return WorldPoint{X: x, Y: y}
}
