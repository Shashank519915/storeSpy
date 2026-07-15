"""Simplified IoU tracker for cloud dev (RIP-2-040 stub)."""

from __future__ import annotations

from dataclasses import dataclass, field
from uuid import uuid4


def iou(a: tuple[float, float, float, float], b: tuple[float, float, float, float]) -> float:
    ax1, ay1, ax2, ay2 = a
    bx1, by1, bx2, by2 = b
    inter_x1 = max(ax1, bx1)
    inter_y1 = max(ay1, by1)
    inter_x2 = min(ax2, bx2)
    inter_y2 = min(ay2, by2)
    if inter_x2 <= inter_x1 or inter_y2 <= inter_y1:
        return 0.0
    inter = (inter_x2 - inter_x1) * (inter_y2 - inter_y1)
    area_a = (ax2 - ax1) * (ay2 - ay1)
    area_b = (bx2 - bx1) * (by2 - by1)
    union = area_a + area_b - inter
    return inter / union if union > 0 else 0.0


@dataclass
class Track:
    track_id: str
    bbox: tuple[float, float, float, float]
    age: int = 0
    lost: int = 0


@dataclass
class SimpleTracker:
    """Single-camera IoU association without ReID (GPU path deferred)."""

    iou_threshold: float = 0.3
    max_lost: int = 30
    tracks: list[Track] = field(default_factory=list)

    def update(self, detections: list[tuple[float, float, float, float]]) -> list[Track]:
        updated: list[Track] = []
        unmatched = set(range(len(detections)))

        for track in self.tracks:
            best_i = -1
            best_score = 0.0
            for i in unmatched:
                score = iou(track.bbox, detections[i])
                if score > best_score:
                    best_score = score
                    best_i = i
            if best_i >= 0 and best_score >= self.iou_threshold:
                track.bbox = detections[best_i]
                track.age += 1
                track.lost = 0
                unmatched.remove(best_i)
                updated.append(track)
            else:
                track.lost += 1
                if track.lost <= self.max_lost:
                    updated.append(track)

        for i in unmatched:
            updated.append(Track(track_id=str(uuid4())[:8], bbox=detections[i], age=1))

        self.tracks = updated
        return self.tracks
