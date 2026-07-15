"""BBox projection helpers (RIP-2-052)."""

from __future__ import annotations

import numpy as np

from orchestrator.spatial.homography import WorldPoint, project_bottom_center


def mock_person_bbox(sequence: int) -> tuple[float, float, float, float]:
    """Deterministic bbox that moves toward shelf ROI as sequence increases."""
    x1 = 100.0 + min(sequence * 2.0, 80.0)
    y1 = 80.0
    x2 = x1 + 60.0
    y2 = 80.0 + 120.0 + min(sequence, 40)
    return x1, y1, x2, y2


def project_person(homography: np.ndarray, bbox: tuple[float, float, float, float]) -> WorldPoint:
    return project_bottom_center(homography, bbox)
