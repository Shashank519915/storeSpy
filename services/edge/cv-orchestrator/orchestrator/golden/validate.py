"""Golden pipeline validation (RIP-2-091/092 cloud path, no GPU)."""

from __future__ import annotations

import json
import sys
from pathlib import Path

import yaml


def validate_event(event: dict, manifest_clip: dict) -> list[str]:
    errors: list[str] = []
    expected = manifest_clip.get("expected_events") or []
    if not expected:
        return errors
    exp = expected[0]
    if event.get("event_type") != exp.get("type"):
        errors.append(f"event_type mismatch: {event.get('event_type')} != {exp.get('type')}")
    payload = event.get("payload") or {}
    if exp.get("shelf_id") and payload.get("shelf_id") != exp.get("shelf_id"):
        errors.append("shelf_id mismatch")
    min_conf = float(exp.get("min_confidence", 0.0))
    if float(payload.get("confidence", 0.0)) < min_conf:
        errors.append(f"confidence below {min_conf}")
    return errors


def main() -> int:
    manifest_path = Path(__file__).resolve().parents[5] / "ml/golden-datasets/manifests/clips.yaml"
    data = yaml.safe_load(manifest_path.read_text(encoding="utf-8"))
    clip = (data.get("clips") or [{}])[0]

    line = sys.stdin.readline()
    if not line.strip():
        print("golden: no event on stdin", file=sys.stderr)
        return 1
    event = json.loads(line)
    errors = validate_event(event, clip)
    if errors:
        for err in errors:
            print(f"golden: {err}", file=sys.stderr)
        return 1
    print("golden: pipeline event matches manifest clip-001")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
