from orchestrator.sampling.fsm import PerceptionFSM, SamplingContext, SamplingState


def test_fsm_idle_to_active_to_interaction() -> None:
    fsm = PerceptionFSM()
    assert fsm.state == SamplingState.IDLE

    state = fsm.tick(SamplingContext(person_detected=True))
    assert state == SamplingState.ACTIVE
    assert fsm.target_fps() == 15.0

    state = fsm.tick(SamplingContext(person_detected=True, hand_in_shelf_roi=True))
    assert state == SamplingState.INTERACTION
    assert fsm.target_fps() == 30.0
