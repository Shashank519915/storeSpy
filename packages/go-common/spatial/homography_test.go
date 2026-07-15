package spatial

import "testing"

func TestProjectBottomCenterIdentity(t *testing.T) {
	h := [9]float64{1, 0, 0, 0, 1, 0, 0, 0, 1}
	pt := ProjectBottomCenter(h, 0.25, 0.25, 0.75, 0.9)
	if pt.X < 0.4 || pt.X > 0.6 {
		t.Fatalf("unexpected x: %v", pt.X)
	}
}
