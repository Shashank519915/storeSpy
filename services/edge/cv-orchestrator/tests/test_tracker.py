from orchestrator.tracking.simple_tracker import SimpleTracker, iou


def test_iou_full_overlap() -> None:
    box = (0.0, 0.0, 10.0, 10.0)
    assert iou(box, box) == 1.0


def test_tracker_assigns_id() -> None:
    tr = SimpleTracker()
    out = tr.update([(10, 10, 50, 80)])
    assert len(out) == 1
    assert out[0].track_id
