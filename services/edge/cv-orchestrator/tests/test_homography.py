import numpy as np

from orchestrator.spatial.homography import (
    PixelPoint,
    WorldPoint,
    compute_homography,
    project_bottom_center,
)


def test_homography_identity_square() -> None:
    pixel = [
        PixelPoint(0, 0),
        PixelPoint(1, 0),
        PixelPoint(1, 1),
        PixelPoint(0, 1),
    ]
    world = [
        WorldPoint(0, 0),
        WorldPoint(1, 0),
        WorldPoint(1, 1),
        WorldPoint(0, 1),
    ]
    h = compute_homography(pixel, world)
    pt = project_bottom_center(h, (0.25, 0.25, 0.75, 0.9))
    assert abs(pt.x - 0.5) < 0.05
    assert abs(pt.y - 0.9) < 0.05
