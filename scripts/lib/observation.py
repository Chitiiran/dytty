"""Observation-period date math for verify-workflow.sh.

Pure functions, no I/O — so they're unit-testable. A malformed date returns a
safe sentinel (never raises, never counts as expired).
"""
import calendar
import time


def days_since(merge_date_str: str, now_epoch: int | None = None) -> int:
    """Whole days between merge_date_str (YYYY-MM-DD, UTC) and now. -1 if unparseable."""
    if now_epoch is None:
        now_epoch = int(time.time())
    try:
        y, m, d = (int(x) for x in merge_date_str.split("-"))
        merge_epoch = calendar.timegm((y, m, d, 0, 0, 0, 0, 0, 0))
    except (ValueError, AttributeError):
        return -1
    return (now_epoch - merge_epoch) // 86400


def is_expired(merge_date_str: str, now_epoch: int, observation_days: int) -> bool:
    """True iff merged at least observation_days ago. Unparseable dates -> False."""
    d = days_since(merge_date_str, now_epoch)
    if d < 0:
        return False
    return d >= observation_days
