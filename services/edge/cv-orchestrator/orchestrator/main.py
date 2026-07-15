"""CLI entrypoint for cloud dev orchestrator ticks."""

from __future__ import annotations

import argparse
import json

from orchestrator.sampling.fsm import PerceptionFSM, SamplingContext


def main() -> None:
    parser = argparse.ArgumentParser(description="cv-orchestrator cloud dev tick")
    parser.add_argument("--person", action="store_true")
    parser.add_argument("--hand-in-shelf", action="store_true")
    parser.add_argument("--idle-frames", type=int, default=0)
    args = parser.parse_args()

    fsm = PerceptionFSM()
    state = fsm.tick(
        SamplingContext(
            person_detected=args.person,
            hand_in_shelf_roi=args.hand_in_shelf,
            idle_frames_without_person=args.idle_frames,
        )
    )
    print(
        json.dumps(
            {
                "state": state.value,
                "target_fps": fsm.target_fps(),
            }
        )
    )


if __name__ == "__main__":
    main()
