"""Unit tests for conflict detection logic."""

from datetime import datetime

import pytest

from app.scheduler.conflict import check_conflict


def _sched(start: tuple, end: tuple, title: str = "Test") -> dict:
    """Helper: build a schedule dict from (Y,M,D,H,Min) tuples."""
    return {
        "start_time": datetime(*start),
        "end_time": datetime(*end),
        "title": title,
    }


class TestNoConflict:
    def test_sequential_events(self):
        """Events that end exactly when the next starts should NOT conflict."""
        new = _sched((2026, 5, 23, 9, 0), (2026, 5, 23, 10, 0))
        existing = [_sched((2026, 5, 23, 10, 0), (2026, 5, 23, 11, 0))]
        assert check_conflict(new, existing) == []

    def test_entirely_before(self):
        new = _sched((2026, 5, 23, 7, 0), (2026, 5, 23, 8, 0))
        existing = [_sched((2026, 5, 23, 9, 0), (2026, 5, 23, 10, 0))]
        assert check_conflict(new, existing) == []

    def test_entirely_after(self):
        new = _sched((2026, 5, 23, 18, 0), (2026, 5, 23, 19, 0))
        existing = [_sched((2026, 5, 23, 9, 0), (2026, 5, 23, 17, 0))]
        assert check_conflict(new, existing) == []

    def test_empty_existing(self):
        new = _sched((2026, 5, 23, 9, 0), (2026, 5, 23, 10, 0))
        assert check_conflict(new, []) == []


class TestConflict:
    def test_partial_overlap_start(self):
        """New event starts before existing ends."""
        new = _sched((2026, 5, 23, 9, 0), (2026, 5, 23, 11, 0))
        existing = [_sched((2026, 5, 23, 10, 0), (2026, 5, 23, 12, 0), "Board meeting")]
        result = check_conflict(new, existing)
        assert len(result) == 1
        assert result[0]["title"] == "Board meeting"

    def test_partial_overlap_end(self):
        """New event starts inside an existing one."""
        new = _sched((2026, 5, 23, 10, 30), (2026, 5, 23, 12, 0))
        existing = [_sched((2026, 5, 23, 9, 0), (2026, 5, 23, 11, 0))]
        assert len(check_conflict(new, existing)) == 1

    def test_new_contains_existing(self):
        """New event completely wraps an existing one."""
        new = _sched((2026, 5, 23, 8, 0), (2026, 5, 23, 18, 0))
        existing = [_sched((2026, 5, 23, 10, 0), (2026, 5, 23, 11, 0))]
        assert len(check_conflict(new, existing)) == 1

    def test_existing_contains_new(self):
        """New event falls entirely inside an existing one."""
        new = _sched((2026, 5, 23, 10, 0), (2026, 5, 23, 11, 0))
        existing = [_sched((2026, 5, 23, 9, 0), (2026, 5, 23, 12, 0))]
        assert len(check_conflict(new, existing)) == 1

    def test_exact_same_time(self):
        new = _sched((2026, 5, 23, 9, 0), (2026, 5, 23, 10, 0))
        existing = [_sched((2026, 5, 23, 9, 0), (2026, 5, 23, 10, 0))]
        assert len(check_conflict(new, existing)) == 1

    def test_multiple_conflicts(self):
        """Only conflicting events are returned; non-conflicting ones are excluded."""
        new = _sched((2026, 5, 23, 9, 0), (2026, 5, 23, 17, 0))
        existing = [
            _sched((2026, 5, 23, 8, 0), (2026, 5, 23, 10, 0), "Morning briefing"),
            _sched((2026, 5, 23, 12, 0), (2026, 5, 23, 14, 0), "Lunch meeting"),
            _sched((2026, 5, 23, 17, 0), (2026, 5, 23, 18, 0), "After-hours call"),
        ]
        result = check_conflict(new, existing)
        titles = {r["title"] for r in result}
        assert titles == {"Morning briefing", "Lunch meeting"}
        assert "After-hours call" not in titles
