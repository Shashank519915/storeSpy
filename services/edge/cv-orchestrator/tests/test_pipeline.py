from orchestrator.detection.mock import detect_from_sequence
from orchestrator.pipeline.runner import build_pickup_event


def test_mock_detection_progression() -> None:
    assert not detect_from_sequence(1).person_detected
    assert detect_from_sequence(10).person_detected
    assert not detect_from_sequence(10).hand_in_shelf_roi
    assert detect_from_sequence(20).hand_in_shelf_roi


def test_build_pickup_event_shape() -> None:
    event = build_pickup_event(
        store_id="s1",
        session_id="sess",
        camera_id="cam",
        track_id="t1",
        sku="sku",
        shelf_id="sh",
        world_x=1.0,
        world_y=2.0,
        confidence=0.9,
    )
    assert event["event_type"] == "vision.interaction.ProductPickedUp"
    assert event["aggregate_type"] == "product_interaction"
    assert event["payload"]["product_sku"] == "sku"
