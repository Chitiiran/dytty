"""Tests for the extracted observation-period date math (scripts/lib/observation.py)."""
import calendar
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "lib"))

from observation import days_since, is_expired  # noqa: E402

# 2026-06-27 00:00:00 UTC as epoch
NOW = calendar.timegm((2026, 6, 27, 0, 0, 0, 0, 0, 0))


def test_days_since_exact_week():
    assert days_since("2026-06-20", NOW) == 7


def test_days_since_zero_today():
    assert days_since("2026-06-27", NOW) == 0


def test_is_expired_at_threshold():
    # exactly 7 days ago, threshold 7 -> expired
    assert is_expired("2026-06-20", NOW, 7) is True


def test_is_expired_below_threshold():
    # 5 days ago, threshold 7 -> not expired
    assert is_expired("2026-06-22", NOW, 7) is False


def test_bad_date_not_expired():
    # malformed date must not crash and must not count as expired
    assert is_expired("not-a-date", NOW, 7) is False


def test_bad_date_days_since_sentinel():
    assert days_since("not-a-date", NOW) == -1


def test_invalid_calendar_date_rejected():
    # impossible dates must be sentinel, not silently rolled over (gemini #242)
    assert days_since("2026-02-30", NOW) == -1
    assert days_since("2026-13-01", NOW) == -1
    assert is_expired("2026-02-30", NOW, 7) is False
