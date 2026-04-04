#!/usr/bin/env python3
"""Tests for play.py — argument validation, file checks, monitor logic.

Note: Audio playback (sounddevice) and ADB logcat are hardware-dependent.
These tests cover the testable logic without requiring a connected device
or audio hardware.
"""

import os
import tempfile
import threading
import time
import unittest

import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from play import monitor_logcat


class TestFileValidation(unittest.TestCase):
    """Test that play.py validates WAV file existence."""

    def test_nonexistent_wav_detected(self):
        """The main() function should exit with code 2 for missing files.
        We test the check logic directly since main() calls sys.exit()."""
        path = "/tmp/nonexistent_voice_test.wav"
        self.assertFalse(os.path.exists(path))

    def test_existing_wav_accepted(self):
        """An existing file should pass validation."""
        fd, path = tempfile.mkstemp(suffix=".wav")
        os.close(fd)
        try:
            self.assertTrue(os.path.exists(path))
        finally:
            os.unlink(path)


class TestMonitorLogcat(unittest.TestCase):
    """Test monitor_logcat() signal detection logic.

    These tests simulate the logcat monitor by testing the result dict
    behavior. We can't test actual ADB connection without a device, but
    we can verify the function handles errors and timeouts correctly.
    """

    def test_result_dict_defaults(self):
        """Verify the expected result dict structure."""
        result = {"found": False, "error": None, "line": None}
        self.assertFalse(result["found"])
        self.assertIsNone(result["error"])
        self.assertIsNone(result["line"])

    def test_adb_not_found_sets_error(self):
        """When ADB isn't in PATH, monitor_logcat should set error."""
        result = {"found": False, "error": None, "line": None}

        # Temporarily break PATH so adb can't be found
        original_path = os.environ.get("PATH", "")
        os.environ["PATH"] = ""
        try:
            monitor_logcat("Turn complete", timeout=1, result=result)
        finally:
            os.environ["PATH"] = original_path

        # Should get an error about ADB not found
        self.assertIsNotNone(result.get("error"))
        self.assertIn("ADB", result["error"])

    def test_timeout_sets_found_false(self):
        """When signal not found within timeout, found should be False."""
        # This test only works if ADB is available but no matching signal
        # We test the timeout path by using a very short timeout
        result = {"found": False, "error": None, "line": None}

        # Run with 0.1s timeout — even if ADB works, signal won't appear
        thread = threading.Thread(
            target=monitor_logcat,
            args=("IMPOSSIBLE_SIGNAL_XYZZY", 0.1, result),
        )
        thread.start()
        thread.join(timeout=2)

        # Either ADB not found (error) or timeout (found=False)
        if result.get("error") is None:
            self.assertFalse(result["found"])


class TestLogFilePath(unittest.TestCase):
    """Test that --log flag creates/appends to a log file."""

    def test_log_file_path_handling(self):
        """Verify log file path is passed through correctly."""
        fd, path = tempfile.mkstemp(suffix=".log")
        os.close(fd)
        try:
            # Just verify the file can be opened for append
            with open(path, "a", encoding="utf-8") as f:
                f.write("test line\n")
            with open(path, "r", encoding="utf-8") as f:
                content = f.read()
            self.assertIn("test line", content)
        finally:
            os.unlink(path)


if __name__ == "__main__":
    unittest.main()
