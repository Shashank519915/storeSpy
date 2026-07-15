"""Temporal confidence filter (RIP-2-061)."""

from __future__ import annotations

from collections import deque


class TemporalFilter:
    """Emit when >= min_agree of last window_size votes are True."""

    def __init__(self, window_size: int = 15, min_agree: int = 11) -> None:
        self._votes: deque[bool] = deque(maxlen=window_size)
        self.window_size = window_size
        self.min_agree = min_agree
        self._emitted = False

    def add_vote(self, vote: bool) -> bool:
        if self._emitted:
            return False
        self._votes.append(vote)
        if len(self._votes) < self.window_size:
            return False
        agree = sum(1 for v in self._votes if v)
        if agree >= self.min_agree:
            self._emitted = True
            return True
        return False
