"""Mock detector for cloud dev (RIP-2-008 virtual path)."""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class Detection:
    person_detected: bool
    hand_in_shelf_roi: bool
    pickup_vote: bool
    confidence: float


def detect_from_sequence(sequence: int) -> Detection:
    """Deterministic mock: person at frame 6+, shelf interaction at 16+, pickup votes in interaction band."""
    person = sequence >= 6
    hand = sequence >= 16
    pickup_vote = sequence >= 18
    confidence = 0.75 if sequence < 18 else 0.92
    return Detection(
        person_detected=person,
        hand_in_shelf_roi=hand,
        pickup_vote=pickup_vote,
        confidence=confidence,
    )
