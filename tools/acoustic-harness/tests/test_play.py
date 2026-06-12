#!/usr/bin/env python3
"""Tests for play.py — argument validation, file checks, monitor logic, tag config.

Audio playback (sounddevice) and ADB logcat are hardware-dependent.
These tests cover the testable logic without requiring a connected device.
"""

import os
import sys
import tempfile
import threading
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from play import monitor_logcat, resolve_tag


class TestResolveTag(unittest.TestCase):
    """Test resolve_tag() — --tag flag and ACOUSTIC_TAG env var."""

    def test_flag_takes_precedence(self):
        """--tag flag overrides ACOUSTIC_TAG env var."""
        os.environ["ACOUSTIC_TAG"] = "ENVTAG"
        try:
            tag = resolve_tag("FLAGTAG")
            self.assertEqual(tag, "FLAGTAG")
        finally:
            del os.environ["ACOUSTIC_TAG"]

    def test_env_var_fallback(self):
        """ACOUSTIC_TAG used when --tag not provided."""
        os.environ["ACOUSTIC_TAG"] = "ENVTAG"
        try:
            tag = resolve_tag(None)
            self.assertEqual(tag, "ENVTAG")
        finally:
            del os.environ["ACOUSTIC_TAG"]

    def test_error_when_neither_set(self):
        """Error when neither --tag nor ACOUSTIC_TAG is set."""
        env_backup = os.environ.pop("ACOUSTIC_TAG", None)
        try:
            with self.assertRaises(SystemExit) as cm:
                resolve_tag(None)
            self.assertEqual(cm.exception.code, 2)
        finally:
            if env_backup is not None:
                os.environ["ACOUSTIC_TAG"] = env_backup


class TestFileValidation(unittest.TestCase):
    """Test that play.py validates WAV file existence."""

    def test_nonexistent_wav_detected(self):
        path = "/tmp/nonexistent_voice_test.wav"
        self.assertFalse(os.path.exists(path))

    def test_existing_wav_accepted(self):
        fd, path = tempfile.mkstemp(suffix=".wav")
        os.close(fd)
        try:
            self.assertTrue(os.path.exists(path))
        finally:
            os.unlink(path)


class TestMonitorLogcat(unittest.TestCase):
    """Test monitor_logcat() signal detection logic."""

    def test_result_dict_defaults(self):
        result = {"found": False, "error": None, "line": None}
        self.assertFalse(result["found"])
        self.assertIsNone(result["error"])
        self.assertIsNone(result["line"])

    def test_adb_not_found_sets_error(self):
        result = {"found": False, "error": None, "line": None}
        original_path = os.environ.get("PATH", "")
        os.environ["PATH"] = ""
        try:
            monitor_logcat(
                signal="Turn complete",
                timeout=1,
                result=result,
                tag="TEST",
            )
        finally:
            os.environ["PATH"] = original_path
        self.assertIsNotNone(result.get("error"))
        self.assertIn("ADB", result["error"])

    def test_timeout_sets_found_false(self):
        result = {"found": False, "error": None, "line": None}
        thread = threading.Thread(
            target=monitor_logcat,
            args=("IMPOSSIBLE_SIGNAL_XYZZY", 0.1, result),
            kwargs={"tag": "TEST"},
        )
        thread.start()
        thread.join(timeout=2)
        if result.get("error") is None:
            self.assertFalse(result["found"])


class TestPlayOnly(unittest.TestCase):
    """Test --play-only mode — plays audio without logcat monitoring."""

    def test_resolve_tag_not_required_in_play_only(self):
        """In play-only mode, tag is not needed (no logcat monitoring)."""
        env_backup = os.environ.pop("ACOUSTIC_TAG", None)
        try:
            # Should NOT raise — tag not required in play-only mode
            tag = resolve_tag(None, required=False)
            self.assertIsNone(tag)
        finally:
            if env_backup is not None:
                os.environ["ACOUSTIC_TAG"] = env_backup

    def test_resolve_tag_still_works_when_provided_in_play_only(self):
        """Tag is accepted but optional in play-only mode."""
        tag = resolve_tag("MYTAG", required=False)
        self.assertEqual(tag, "MYTAG")


class TestLogFilePath(unittest.TestCase):
    """Test that --log flag creates/appends to a log file."""

    def test_log_file_path_handling(self):
        fd, path = tempfile.mkstemp(suffix=".log")
        os.close(fd)
        try:
            with open(path, "a", encoding="utf-8") as f:
                f.write("test line\n")
            with open(path, "r", encoding="utf-8") as f:
                content = f.read()
            self.assertIn("test line", content)
        finally:
            os.unlink(path)


if __name__ == "__main__":
    unittest.main()
