"""Wired cloud dev pipeline: stdin frame ticks -> FSM -> stdout event envelope."""

from __future__ import annotations

import json
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from orchestrator.config import load_edge_flags
from orchestrator.detection.mock import detect_from_sequence
from orchestrator.interaction.product_fsm import ProductFSM
from orchestrator.interaction.temporal_filter import TemporalFilter
from orchestrator.sampling.fsm import PerceptionFSM, SamplingContext
from orchestrator.spatial.calibration_loader import load_calibration
from orchestrator.spatial.project import mock_person_bbox, project_person
from orchestrator.tracking.simple_tracker import SimpleTracker


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[5]


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def build_pickup_event(
    *,
    store_id: str,
    session_id: str,
    camera_id: str,
    track_id: str,
    sku: str,
    shelf_id: str,
    world_x: float,
    world_y: float,
    confidence: float,
) -> dict[str, Any]:
    return {
        "event_id": str(uuid.uuid4()),
        "trace_id": str(uuid.uuid4()),
        "span_id": str(uuid.uuid4()).replace("-", "")[:16],
        "occurred_at": _utc_now(),
        "ingested_at": _utc_now(),
        "store_id": store_id,
        "session_id": session_id,
        "schema_version": "v1",
        "event_type": "vision.interaction.ProductPickedUp",
        "aggregate_type": "product_interaction",
        "aggregate_id": track_id,
        "payload": {
            "camera_id": camera_id,
            "track_id": track_id,
            "product_sku": sku,
            "shelf_id": shelf_id,
            "world_x": world_x,
            "world_y": world_y,
            "confidence": confidence,
        },
    }


def run() -> int:
    flags = load_edge_flags()
    store_id = str(flags.get("store_id", "store-dev-01"))
    session_id = str(flags.get("session_id", "session-dev-01"))
    camera_id = str(flags.get("virtual_camera_id", "cam-virtual-01"))

    cal_path = _repo_root() / "ml/golden-datasets/manifests/calibration-stub.json"
    calibration = load_calibration(cal_path)
    shelf_id = "shelf-a1"
    if calibration.shelf_rois:
        shelf_id = calibration.shelf_rois[0].get("shelf_id", shelf_id)

    fsm = PerceptionFSM()
    product = ProductFSM()
    temporal = TemporalFilter()
    tracker = SimpleTracker()
    idle_without_person = 0
    emitted = False
    active_track_id = "track-001"

    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        tick = json.loads(line)
        seq = int(tick.get("sequence", 0))
        cam = tick.get("camera_id", camera_id)

        det = detect_from_sequence(seq)
        if det.person_detected:
            idle_without_person = 0
            bbox = mock_person_bbox(seq)
            tracks = tracker.update([bbox])
            if tracks:
                active_track_id = tracks[0].track_id
            world = project_person(calibration.homography, bbox)
        else:
            idle_without_person += 1
            world = None

        state = fsm.tick(
            SamplingContext(
                person_detected=det.person_detected,
                hand_in_shelf_roi=det.hand_in_shelf_roi,
                idle_frames_without_person=idle_without_person,
            )
        )

        if state.value == "interaction" and det.pickup_vote:
            if temporal.add_vote(True):
                product.apply_pickup_vote(True)
                wx = world.x if world else 1.2
                wy = world.y if world else 3.4
                event = build_pickup_event(
                    store_id=store_id,
                    session_id=session_id,
                    camera_id=cam,
                    track_id=active_track_id,
                    sku="SKU-DEMO-001",
                    shelf_id=shelf_id,
                    world_x=wx,
                    world_y=wy,
                    confidence=det.confidence,
                )
                sys.stdout.write(json.dumps(event) + "\n")
                sys.stdout.flush()
                emitted = True
        elif state.value == "interaction":
            temporal.add_vote(False)

    if not emitted:
        sys.stderr.write("pipeline-runner: no pickup event emitted\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(run())
