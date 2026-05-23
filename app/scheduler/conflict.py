"""Conflict detection for calendar schedules.

A conflict occurs when a new event's time range overlaps with any existing
event. Two intervals [A_start, A_end) and [B_start, B_end) overlap when:

    A_start < B_end  AND  A_end > B_start

This is the standard interval-overlap predicate.
"""

from datetime import datetime
from typing import Any, Dict, List


def check_conflict(
    new_schedule: Dict[str, Any],
    existing_schedules: List[Dict[str, Any]],
) -> List[Dict[str, Any]]:
    """Return a list of existing schedules that overlap with `new_schedule`.

    Parameters
    ----------
    new_schedule:
        Dict with at least ``start_time`` and ``end_time`` (datetime) keys.
    existing_schedules:
        List of dicts with the same keys. Any additional keys (e.g. ``title``)
        are preserved in the returned conflicts so callers can surface them.

    Returns
    -------
    list
        Subset of ``existing_schedules`` that conflict with the new event.
        Empty list means no conflicts.

    Examples
    --------
    >>> from datetime import datetime
    >>> new = {"start_time": datetime(2026, 5, 23, 9), "end_time": datetime(2026, 5, 23, 11)}
    >>> existing = [{"start_time": datetime(2026, 5, 23, 10), "end_time": datetime(2026, 5, 23, 12), "title": "Board meeting"}]
    >>> check_conflict(new, existing)
    [{'start_time': ..., 'end_time': ..., 'title': 'Board meeting'}]
    """
    new_start: datetime = new_schedule["start_time"]
    new_end: datetime = new_schedule["end_time"]

    conflicts: List[Dict[str, Any]] = []
    for sched in existing_schedules:
        existing_start: datetime = sched["start_time"]
        existing_end: datetime = sched["end_time"]

        # Classic interval overlap: they touch at a boundary → no conflict
        if new_start < existing_end and new_end > existing_start:
            conflicts.append(sched)

    return conflicts
