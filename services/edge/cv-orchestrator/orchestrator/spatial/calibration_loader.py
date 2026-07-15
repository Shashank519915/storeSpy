"""Load camera calibration stub (RIP-2-055)."""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path

import numpy as np

from orchestrator.spatial.homography import load_calibration_stub


@dataclass(frozen=True)
class CameraCalibration:
    camera_id: str
    store_id: str
    homography: np.ndarray
    shelf_rois: list[dict]


def load_calibration(path: str | Path) -> CameraCalibration:
    path = Path(path)
    data = json.loads(path.read_text(encoding="utf-8"))
    return CameraCalibration(
        camera_id=data.get("camera_id", "cam-virtual-01"),
        store_id=data.get("store_id", "store-dev-01"),
        homography=load_calibration_stub(path),
        shelf_rois=data.get("shelf_rois", []),
    )
