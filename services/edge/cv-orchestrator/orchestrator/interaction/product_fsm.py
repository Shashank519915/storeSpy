"""Product interaction state machine (RIP-2-060)."""

from __future__ import annotations

from enum import Enum


class ProductState(str, Enum):
    ON_SHELF = "on_shelf"
    IN_HAND = "in_hand"
    IN_CART = "in_cart"
    RETURNED = "returned"


class ProductFSM:
    def __init__(self) -> None:
        self.state = ProductState.ON_SHELF

    def apply_pickup_vote(self, voted: bool) -> ProductState | None:
        if voted and self.state == ProductState.ON_SHELF:
            self.state = ProductState.IN_HAND
            return self.state
        return None
