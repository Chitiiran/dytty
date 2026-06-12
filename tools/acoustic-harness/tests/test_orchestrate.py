#!/usr/bin/env python3
"""Tests for orchestrate.py — logcat trigger, scenario config parsing."""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from orchestrate import (
    LogcatTrigger,
    PreloadedAudio,
    parse_scenario_config,
    play_audio,
    run_with_retries,
)


class TestLogcatTrigger(unittest.TestCase):
    """Test LogcatTrigger — fires callback when signal detected."""

    def test_trigger_fires_on_signal(self):
        triggered = {"fired": False}
        trigger = LogcatTrigger(
            signal="Voice note state: listening",
            tag="DYTTY",
            callback=lambda l: triggered.__setitem__("fired", True),
        )
        trigger.process_line("[DYTTY] Voice note state: listening")
        self.assertTrue(triggered["fired"])

    def test_trigger_ignores_other_signals(self):
        triggered = {"fired": False}
        trigger = LogcatTrigger(
            signal="Voice note state: listening",
            tag="DYTTY",
            callback=lambda l: triggered.__setitem__("fired", True),
        )
        trigger.process_line("[DYTTY] Call state: active")
        trigger.process_line("Some random log")
        self.assertFalse(triggered["fired"])

    def test_trigger_ignores_wrong_tag(self):
        triggered = {"fired": False}
        trigger = LogcatTrigger(
            signal="Voice note state: listening",
            tag="DYTTY",
            callback=lambda l: triggered.__setitem__("fired", True),
        )
        trigger.process_line("[OTHER] Voice note state: listening")
        self.assertFalse(triggered["fired"])

    def test_trigger_fires_only_once(self):
        count = {"n": 0}
        trigger = LogcatTrigger(
            signal="listening",
            tag="DYTTY",
            callback=lambda l: count.__setitem__("n", count["n"] + 1),
        )
        trigger.process_line("[DYTTY] Voice note state: listening")
        trigger.process_line("[DYTTY] Voice note state: listening")
        self.assertEqual(count["n"], 1)

    def test_trigger_rearm_allows_second_fire(self):
        count = {"n": 0}
        trigger = LogcatTrigger(
            signal="listening",
            tag="DYTTY",
            callback=lambda l: count.__setitem__("n", count["n"] + 1),
        )
        trigger.process_line("[DYTTY] Voice note state: listening")
        trigger.rearm()
        trigger.process_line("[DYTTY] Voice note state: listening")
        self.assertEqual(count["n"], 2)

    def test_fired_property(self):
        trigger = LogcatTrigger(
            signal="listening",
            tag="DYTTY",
            callback=lambda l: None,
        )
        self.assertFalse(trigger.fired)
        trigger.process_line("[DYTTY] Voice note state: listening")
        self.assertTrue(trigger.fired)

    def test_trigger_with_logcat_prefix(self):
        """Real logcat lines have timestamp prefix before the tag."""
        triggered = {"fired": False}
        trigger = LogcatTrigger(
            signal="Call state: active",
            tag="DYTTY",
            callback=lambda l: triggered.__setitem__("fired", True),
        )
        trigger.process_line(
            "04-04 12:00:01.000 V/flutter: [DYTTY] Call state: active"
        )
        self.assertTrue(triggered["fired"])


class TestParseScenarioConfig(unittest.TestCase):
    """Test parse_scenario_config — maps scenario to orchestration config."""

    def test_voice_note_scenario(self):
        scenario = {
            "name": "voice-note-basic",
            "path": "voice-note",
            "utterances": [{"text": "hello", "expect": {}}],
        }
        config = parse_scenario_config(scenario)
        self.assertEqual(config["trigger_signal"], "Voice note state: listening")
        self.assertEqual(config["flow_type"], "voice-note")
        self.assertFalse(config["needs_logcat_verify"])

    def test_daily_call_scenario(self):
        scenario = {
            "name": "basic-call-liveness",
            "path": "daily-call",
            "utterances": [{"text": "hello", "expect": {}}],
        }
        config = parse_scenario_config(scenario)
        self.assertEqual(config["trigger_signal"], "Call state: active")
        self.assertEqual(config["flow_type"], "daily-call")
        self.assertTrue(config["needs_logcat_verify"])

    def test_unknown_path_defaults_to_daily_call(self):
        scenario = {
            "name": "unknown",
            "path": "something-else",
            "utterances": [],
        }
        config = parse_scenario_config(scenario)
        self.assertEqual(config["trigger_signal"], "Call state: active")
        self.assertTrue(config["needs_logcat_verify"])


class _FakeSd:
    """Stand-in for sounddevice: records calls, no audio hardware."""

    def __init__(self):
        self.played = []
        self.waited = 0
        self.streams_opened = 0

    def play(self, data, samplerate):
        self.played.append((data, samplerate))

    def wait(self):
        self.waited += 1

    class _Stream:
        def __init__(self, outer):
            self.outer = outer

        def __enter__(self):
            self.outer.streams_opened += 1
            return self

        def __exit__(self, *a):
            return False

    def OutputStream(self, **kwargs):
        return _FakeSd._Stream(self)


def _write_temp_wav(path):
    import struct
    import wave

    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(16000)
        w.writeframes(struct.pack("<" + "h" * 1600, *([1000] * 1600)))


class TestPreloadedAudio(unittest.TestCase):
    """Trigger-time playback must not pay subprocess/import/file-read cost
    inside the app's listening window (over-air timing race)."""

    def setUp(self):
        import tempfile

        self.tmp = tempfile.mkdtemp()
        self.wav = os.path.join(self.tmp, "t.wav")
        _write_temp_wav(self.wav)

    def test_loads_wav_and_warms_device_at_construction(self):
        sd = _FakeSd()
        audio = PreloadedAudio(self.wav, sd_module=sd)
        self.assertGreater(len(audio.data), 0)
        self.assertEqual(audio.samplerate, 16000)
        self.assertEqual(sd.streams_opened, 1, "device must be warmed eagerly")
        self.assertEqual(sd.played, [], "construction must not play")

    def test_play_blocking_uses_preloaded_data(self):
        sd = _FakeSd()
        audio = PreloadedAudio(self.wav, sd_module=sd)
        audio.play_blocking()
        self.assertEqual(len(sd.played), 1)
        data, rate = sd.played[0]
        self.assertIs(data, audio.data, "must play the preloaded buffer")
        self.assertEqual(rate, 16000)
        self.assertEqual(sd.waited, 1)

    def test_play_audio_prefers_preloaded_over_subprocess(self):
        sd = _FakeSd()
        audio = PreloadedAudio(self.wav, sd_module=sd)
        rc = play_audio(self.wav, play_only=True, preloaded=audio)
        self.assertEqual(rc, 0)
        self.assertEqual(len(sd.played), 1, "no subprocess; in-process play")


if __name__ == "__main__":
    unittest.main()


class TestRunWithRetries(unittest.TestCase):
    """Over-air audio gives each attempt ~85-90% reliability; a single
    retry is the difference between a usable nightly and noise."""

    def test_first_pass_runs_once(self):
        calls = {"n": 0}

        def attempt():
            calls["n"] += 1
            return 0

        self.assertEqual(run_with_retries(attempt, retries=1), 0)
        self.assertEqual(calls["n"], 1)

    def test_fail_then_pass_retries_and_succeeds(self):
        calls = {"n": 0}

        def attempt():
            calls["n"] += 1
            return 1 if calls["n"] == 1 else 0

        self.assertEqual(run_with_retries(attempt, retries=1), 0)
        self.assertEqual(calls["n"], 2)

    def test_persistent_failure_returns_nonzero(self):
        self.assertEqual(run_with_retries(lambda: 7, retries=2), 7)

    def test_zero_retries_single_attempt(self):
        calls = {"n": 0}

        def attempt():
            calls["n"] += 1
            return 1

        self.assertEqual(run_with_retries(attempt, retries=0), 1)
        self.assertEqual(calls["n"], 1)


class TestRunMaestroWatchdog(unittest.TestCase):
    """A wedged Maestro daemon must fail the attempt, not hang the
    harness forever (observed: 83-minute hang holding the device)."""

    def test_timeout_kills_and_returns_124(self):
        from unittest import mock
        import subprocess as sp

        from orchestrate import run_maestro

        fake_proc = mock.Mock()
        fake_proc.pid = 1
        fake_proc.communicate.side_effect = [
            sp.TimeoutExpired(cmd="maestro", timeout=5),
            ("", ""),
        ]
        with mock.patch("orchestrate.subprocess.Popen",
                        return_value=fake_proc), \
                mock.patch("orchestrate._kill_tree"):
            rc = run_maestro("flow.yaml", timeout_seconds=5)
        self.assertEqual(rc, 124)

    def test_passes_timeout_to_communicate(self):
        from unittest import mock

        from orchestrate import run_maestro

        fake_proc = mock.Mock()
        fake_proc.pid = 1
        fake_proc.communicate.return_value = ("", "")
        fake_proc.returncode = 0
        with mock.patch("orchestrate.subprocess.Popen",
                        return_value=fake_proc):
            run_maestro("flow.yaml", timeout_seconds=77)
        self.assertEqual(
            fake_proc.communicate.call_args.kwargs.get("timeout"), 77
        )


class TestMonitorProcHolder(unittest.TestCase):
    """A retry must be able to kill the previous attempt's adb logcat —
    a thread blocked in readline() survives stop_event + join(5) and
    poisons the next attempt (double audio fire, two session.log
    writers)."""

    def test_holder_receives_popen_for_external_kill(self):
        import tempfile
        import threading
        from unittest import mock

        from orchestrate import run_logcat_monitor

        fake_proc = mock.Mock()
        fake_proc.stdout = None  # loop exits immediately on None stdout
        fake_proc.poll.return_value = 0
        with mock.patch("orchestrate.subprocess.Popen", return_value=fake_proc):
            holder = {}
            run_logcat_monitor(
                "DYTTY", [], os.path.join(tempfile.mkdtemp(), "l.log"),
                threading.Event(), proc_holder=holder,
            )
        self.assertIs(holder.get("proc"), fake_proc)


class TestKillTree(unittest.TestCase):
    """Watchdog must kill the Maestro JVM grandchild, not just the
    launcher — otherwise the wedged daemon it guards against is
    recreated for every following flow."""

    def test_windows_uses_taskkill_tree(self):
        from unittest import mock

        from orchestrate import _kill_tree

        with mock.patch("orchestrate.subprocess.run") as m,                 mock.patch("orchestrate.sys.platform", "win32"):
            _kill_tree(4242)
        cmd = m.call_args.args[0]
        self.assertIn("taskkill", cmd[0])
        self.assertIn("/T", cmd)
        self.assertIn("4242", cmd)

    def test_run_maestro_timeout_kills_tree_returns_124(self):
        from unittest import mock
        import subprocess as sp

        from orchestrate import run_maestro

        fake_proc = mock.Mock()
        fake_proc.pid = 777
        fake_proc.communicate.side_effect = [
            sp.TimeoutExpired(cmd="maestro", timeout=1),
            ("", ""),
        ]
        with mock.patch("orchestrate.subprocess.Popen",
                        return_value=fake_proc),                 mock.patch("orchestrate._kill_tree") as kt:
            rc = run_maestro("flow.yaml", timeout_seconds=1)
        self.assertEqual(rc, 124)
        kt.assert_called_once_with(777)


class TestKillTreePosixSafety(unittest.TestCase):
    """killpg on the orchestrator's own process group is suicide; the
    child must be started in a new session and the guard must refuse
    same-group kills."""

    def test_posix_guard_refuses_own_process_group(self):
        from unittest import mock

        import orchestrate

        with mock.patch.object(orchestrate.sys, "platform", "linux"),                 mock.patch.object(orchestrate.os, "getpgid",
                                  return_value=555, create=True),                 mock.patch.object(orchestrate.os, "getpgrp",
                                  return_value=555, create=True),                 mock.patch.object(orchestrate.os, "killpg",
                                  create=True) as kp:
            orchestrate._kill_tree(123)
        kp.assert_not_called()

    def test_posix_kills_foreign_process_group(self):
        from unittest import mock

        import orchestrate

        with mock.patch.object(orchestrate.sys, "platform", "linux"),                 mock.patch.object(orchestrate.os, "getpgid",
                                  return_value=555, create=True),                 mock.patch.object(orchestrate.os, "getpgrp",
                                  return_value=999, create=True),                 mock.patch.object(orchestrate.os, "killpg",
                                  create=True) as kp:
            orchestrate._kill_tree(123)
        kp.assert_called_once()

    def test_maestro_child_starts_new_session(self):
        from unittest import mock

        from orchestrate import run_maestro

        fake_proc = mock.Mock()
        fake_proc.pid = 1
        fake_proc.communicate.return_value = ("", "")
        fake_proc.returncode = 0
        with mock.patch("orchestrate.subprocess.Popen",
                        return_value=fake_proc) as popen:
            run_maestro("flow.yaml", timeout_seconds=5)
        self.assertTrue(popen.call_args.kwargs.get("start_new_session"))
