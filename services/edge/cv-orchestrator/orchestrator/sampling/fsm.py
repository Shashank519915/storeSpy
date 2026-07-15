"""Per-camera perception sampling state machine (RIP-2-030)."""

from __future__ import annotations

from dataclasses import dataclass
from enum import Enum


class SamplingState(str, Enum):
    IDLE = "idle"
    ACTIVE = "active"
    INTERACTION = "interaction"


@dataclass
class SamplingContext:
    person_detected: bool = False
    hand_in_shelf_roi: bool = False
    idle_frames_without_person: int = 0
    idle_timeout_frames: int = 300  # ~30s at 10fps orchestrator tick


class PerceptionFSM:
    """Idle -> Active -> Interaction transitions for dynamic frame sampling."""

    def __init__(self) -> None:
        self.state = SamplingState.IDLE

    def tick(self, ctx: SamplingContext) -> SamplingState:
        if self.state == SamplingState.IDLE:
            if ctx.person_detected:
                self.state = SamplingState.ACTIVE
        elif self.state == SamplingState.ACTIVE:
            if ctx.hand_in_shelf_roi:
                self.state = SamplingState.INTERACTION
            elif ctx.idle_frames_without_person >= ctx.idle_timeout_frames:
                self.state = SamplingState.IDLE
        elif self.state == SamplingState.INTERACTION:
            if not ctx.hand_in_shelf_roi and not ctx.person_detected:
                self.state = SamplingState.IDLE
            elif not ctx.hand_in_shelf_roi and ctx.person_detected:
                self.state = SamplingState.ACTIVE

        return self.state

    def target_fps(self) -> float:
        if self.state == SamplingState.IDLE:
            return 1.0
        if self.state == SamplingState.ACTIVE:
            return 15.0
        return 30.0
