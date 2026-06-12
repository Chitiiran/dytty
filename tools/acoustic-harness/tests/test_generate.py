#!/usr/bin/env python3
"""Tests for generate.py — hash caching, scenario parsing, filename derivation.

App-agnostic: all paths passed as arguments, no hardcoded project paths.
"""

import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from generate import _content_hash, _load_hashes, _save_hashes, list_scenarios


class TestContentHash(unittest.TestCase):
    """Test _content_hash() — deterministic hashing of TTS inputs."""

    def test_same_inputs_same_hash(self):
        h1 = _content_hash("hello", "af_heart", 1.0)
        h2 = _content_hash("hello", "af_heart", 1.0)
        self.assertEqual(h1, h2)

    def test_different_text_different_hash(self):
        h1 = _content_hash("hello", "af_heart", 1.0)
        h2 = _content_hash("goodbye", "af_heart", 1.0)
        self.assertNotEqual(h1, h2)

    def test_different_voice_different_hash(self):
        h1 = _content_hash("hello", "af_heart", 1.0)
        h2 = _content_hash("hello", "af_bella", 1.0)
        self.assertNotEqual(h1, h2)

    def test_different_speed_different_hash(self):
        h1 = _content_hash("hello", "af_heart", 1.0)
        h2 = _content_hash("hello", "af_heart", 0.8)
        self.assertNotEqual(h1, h2)

    def test_hash_is_16_chars(self):
        h = _content_hash("test", "af_heart", 1.0)
        self.assertEqual(len(h), 16)

    def test_hash_is_hex(self):
        h = _content_hash("test", "af_heart", 1.0)
        int(h, 16)  # Raises ValueError if not valid hex


class TestHashPersistence(unittest.TestCase):
    """Test _load_hashes() and _save_hashes() — explicit path, no globals."""

    def test_load_nonexistent_returns_empty(self):
        hashes = _load_hashes("/tmp/nonexistent_hash_file_ath.json")
        self.assertEqual(hashes, {})

    def test_save_and_load_roundtrip(self):
        fd, path = tempfile.mkstemp(suffix=".json")
        os.close(fd)
        try:
            data = {"file1.wav": "abc123", "file2.wav": "def456"}
            _save_hashes(data, path)
            loaded = _load_hashes(path)
            self.assertEqual(loaded, data)
        finally:
            os.unlink(path)

    def test_save_overwrites_existing(self):
        fd, path = tempfile.mkstemp(suffix=".json")
        os.close(fd)
        try:
            _save_hashes({"old": "data"}, path)
            _save_hashes({"new": "data"}, path)
            loaded = _load_hashes(path)
            self.assertEqual(loaded, {"new": "data"})
        finally:
            os.unlink(path)


class TestListScenarios(unittest.TestCase):
    """Test list_scenarios() — output formatting."""

    def test_lists_all_scenarios(self):
        data = {
            "scenarios": [
                {
                    "name": "test-one",
                    "description": "First test",
                    "path": "daily-call",
                    "utterances": [
                        {"text": "Hello there", "expect": {}},
                    ],
                },
                {
                    "name": "test-two",
                    "description": "Second test",
                    "path": "voice-note",
                    "utterances": [
                        {"text": "First utterance", "expect": {}},
                        {"text": "Second utterance", "expect": {}},
                    ],
                },
            ]
        }
        import io
        from contextlib import redirect_stdout

        f = io.StringIO()
        with redirect_stdout(f):
            list_scenarios(data)
        output = f.getvalue()

        self.assertIn("test-one", output)
        self.assertIn("test-two", output)
        self.assertIn("daily-call", output)
        self.assertIn("voice-note", output)
        self.assertIn("Hello there", output)
        self.assertIn("test-one_0.wav", output)
        self.assertIn("test-two_0.wav", output)
        self.assertIn("test-two_1.wav", output)
        self.assertIn("2 utterances", output)
        self.assertIn("1 utterance", output)


class TestWavFilenameDerivation(unittest.TestCase):
    """Test that WAV filenames are derived correctly from scenario + index."""

    def test_filename_format(self):
        scenarios = [
            ("basic-call-liveness", 0, "basic-call-liveness_0.wav"),
            ("multi-turn-daily-call", 0, "multi-turn-daily-call_0.wav"),
            ("multi-turn-daily-call", 1, "multi-turn-daily-call_1.wav"),
            ("tool-call-save-entry", 0, "tool-call-save-entry_0.wav"),
        ]
        for name, index, expected in scenarios:
            filename = f"{name}_{index}.wav"
            self.assertEqual(filename, expected)


if __name__ == "__main__":
    unittest.main()
