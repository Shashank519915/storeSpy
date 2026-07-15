"""Homography calibration and projection (RIP-2-050..055)."""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path

import numpy as np


@dataclass(frozen=True)
class PixelPoint:
    u: float
    v: float


@dataclass(frozen=True)
class WorldPoint:
    x: float
    y: float


def compute_homography(pixel_pts: list[PixelPoint], world_pts: list[WorldPoint]) -> np.ndarray:
    """Direct Linear Transform for >=4 point correspondences."""
    if len(pixel_pts) != len(world_pts) or len(pixel_pts) < 4:
        raise ValueError("need >=4 corresponding point pairs")

    rows: list[list[float]] = []
    for px, wy in zip(pixel_pts, world_pts, strict=True):
        rows.append([-px.u, -px.v, -1, 0, 0, 0, wy.x * px.u, wy.x * px.v, wy.x])
        rows.append([0, 0, 0, -px.u, -px.v, -1, wy.y * px.u, wy.y * px.v, wy.y])

    _, _, vt = np.linalg.svd(np.array(rows, dtype=np.float64))
    h = vt[-1].reshape(3, 3)
    return h / h[2, 2]


def project_bottom_center(h: np.ndarray, bbox: tuple[float, float, float, float]) -> WorldPoint:
    """Project bbox bottom-center pixel to world meters."""
    x1, y1, x2, y2 = bbox
    u = (x1 + x2) / 2.0
    v = y2
    vec = np.array([u, v, 1.0], dtype=np.float64)
    out = h @ vec
    if abs(out[2]) < 1e-9:
        raise ValueError("degenerate homography projection")
    return WorldPoint(x=float(out[0] / out[2]), y=float(out[1] / out[2]))


def load_calibration_stub(path: str | Path) -> np.ndarray:
    """Load homography matrix from twin stub JSON."""
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    matrix = data.get("homography_matrix")
    if not matrix:
        raise KeyError("homography_matrix missing in calibration stub")
    return np.array(matrix, dtype=np.float64)
