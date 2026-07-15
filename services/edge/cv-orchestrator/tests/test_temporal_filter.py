from orchestrator.interaction.temporal_filter import TemporalFilter


def test_temporal_filter_emits_once() -> None:
    filt = TemporalFilter(window_size=5, min_agree=4)
    assert not filt.add_vote(True)
    assert not filt.add_vote(True)
    assert not filt.add_vote(True)
    assert not filt.add_vote(False)
    assert filt.add_vote(True)
    assert not filt.add_vote(True)
