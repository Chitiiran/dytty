#!/usr/bin/env python3
"""Orchestrate voice E2E tests — coordinate Maestro, audio playback, and logcat.

Usage:
    python orchestrate.py \
      --scenario basic-call-liveness \
      --scripts test/fixtures/audio/test-scripts.json \
      --wavs test/fixtures/audio/generated/ \
      --flow .maestro/voice/daily-call-liveness.yaml \
      --tag DYTTY

The orchestrator:
  1. Clears logcat
  2. Starts background logcat capture
  3. Launches Maestro (UI-only flow) as a subprocess
  4. Monitors logcat for trigger signal (e.g., "listening", "Call state: active")
  5. Plays audio via play.py when trigger fires
  6. Waits for Maestro to complete (UI assertions)
  7. Runs verify.py for daily call scenarios (logcat-based)
  8. Reports results

Exit codes:
    0 — All checks passed
    1 — Test failed (Maestro or verification)
    2 — Error (config, ADB, etc.)
"""

import argparse
import json
import os
import subprocess
import sys
import threading
import time


SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))


class LogcatTrigger:
    """Watch logcat lines for a signal and fire a callback once."""

    def __init__(self, signal: str, tag: str, callback):
        self.signal = signal
        self.tag = tag
        self.callback = callback
        self._fired = False
        self._tag_marker = f"[{tag}]"

    def process_line(self, line: str) -> None:
        """Process a logcat line. Fires callback if signal matches."""
        if self._fired:
            return
        if self._tag_marker not in line:
            return
        if self.signal in line:
            self._fired = True
            self.callback(line)

    def rearm(self) -> None:
        """Allow the trigger to fire again (for multi-utterance scenarios)."""
        self._fired = False

    @property
    def fired(self) -> bool:
        return self._fired


def parse_scenario_config(scenario: dict) -> dict:
    """Map a test-scripts.json scenario to orchestration config.

    Returns dict with:
        trigger_signal: logcat signal to watch for before playing audio
        flow_type: "voice-note" or "daily-call"
        needs_logcat_verify: whether to run verify.py after
    """
    path = scenario.get("path", "")

    if path == "voice-note":
        return {
            "trigger_signal": "Voice note state: listening",
            "flow_type": "voice-note",
            "needs_logcat_verify": False,
        }
    elif path == "daily-call":
        return {
            "trigger_signal": "Call state: active",
            "flow_type": "daily-call",
            "needs_logcat_verify": True,
        }
    else:
        return {
            "trigger_signal": "Call state: active",
            "flow_type": path,
            "needs_logcat_verify": True,
        }


def run_logcat_monitor(
    tag: str,
    triggers: list[LogcatTrigger],
    log_path: str,
    stop_event: threading.Event,
    proc_holder: dict | None = None,
) -> None:
    """Background thread: stream logcat, feed lines to triggers, write to log.

    proc_holder (if given) receives the adb Popen under key "proc" so
    the owner can kill it from outside: a thread blocked in readline()
    never re-checks stop_event, survives join(timeout), and poisons the
    next retry attempt (stale trigger double-fires audio; two writers
    corrupt session.log).
    """
    try:
        proc = subprocess.Popen(
            ["adb", "logcat", "-v", "time", "flutter:V", "*:S"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1,
        )
    except FileNotFoundError:
        print("ERROR: ADB not found in PATH")
        return
    if proc_holder is not None:
        proc_holder["proc"] = proc

    tag_marker = f"[{tag}]"

    with open(log_path, "w", encoding="utf-8") as log_file:
        try:
            while not stop_event.is_set():
                if proc.stdout is None:
                    break
                line = proc.stdout.readline()
                if not line:
                    if proc.poll() is not None:
                        break
                    continue

                # Write all Flutter lines to log
                log_file.write(line)
                log_file.flush()

                # Feed tagged lines to triggers
                if tag_marker in line:
                    for trigger in triggers:
                        trigger.process_line(line.strip())
        finally:
            proc.terminate()
            try:
                proc.wait(timeout=3)
            except subprocess.TimeoutExpired:
                proc.kill()


class PreloadedAudio:
    """WAV pre-loaded into memory with the output device warmed up.

    Trigger-time playback must start within the app's STT listening
    window; spawning a play.py subprocess at trigger time pays
    interpreter start + PortAudio init + file read (seconds) inside
    that window and loses the race (observed: voice-note flows
    intermittently never reach transcriptReview). Construct this
    BEFORE launching the flow; play_blocking() then starts in
    milliseconds.
    """

    def __init__(self, wav_path: str, sd_module=None):
        import soundfile as sf

        if sd_module is None:
            import sounddevice as sd_module
        self._sd = sd_module
        self.data, self.samplerate = sf.read(wav_path)
        channels = self.data.shape[1] if self.data.ndim > 1 else 1
        # Open/close a stream now so the first real play() does not pay
        # PortAudio device initialization.
        with self._sd.OutputStream(
            samplerate=self.samplerate, channels=channels
        ):
            pass

    def play_blocking(self) -> None:
        self._sd.play(self.data, self.samplerate)
        self._sd.wait()


def play_audio(
    wav_path: str,
    play_only: bool = False,
    tag: str | None = None,
    preloaded: "PreloadedAudio | None" = None,
) -> int:
    """Play audio. Prefers the pre-warmed in-process path; falls back to
    a play.py subprocess for paths that also monitor logcat (daily call
    --wait-for), which are not start-latency critical."""
    if preloaded is not None and play_only:
        print(f"  Playing (preloaded): {os.path.basename(wav_path)}")
        preloaded.play_blocking()
        return 0

    cmd = [sys.executable, os.path.join(SCRIPT_DIR, "play.py"), "--wav", wav_path]

    if play_only:
        cmd.extend(["--play-only", "--delay", "0"])
    else:
        cmd.extend(["--wait-for", "Turn complete", "--timeout", "15", "--delay", "0"])
        if tag:
            cmd.extend(["--tag", tag])

    print(f"  Playing: {os.path.basename(wav_path)}")
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.stdout:
        for line in result.stdout.strip().split("\n"):
            print(f"    {line}")
    if result.returncode != 0 and result.stderr:
        print(f"    STDERR: {result.stderr.strip()}")
    return result.returncode


def run_with_retries(attempt, retries: int) -> int:
    """Run attempt() up to 1 + retries times until it returns 0.

    Over-air audio gives each attempt imperfect reliability (volume,
    room noise, STT variance); one retry turns a ~90%-reliable flow
    into a ~99%-reliable check without masking real regressions —
    deterministic failures still fail every attempt.
    """
    rc = attempt()
    for n in range(retries):
        if rc == 0:
            break
        print(f"  RETRY {n + 1}/{retries}: previous attempt failed")
        rc = attempt()
    return rc


def _find_maestro() -> str:
    """Find the maestro executable, checking common locations."""
    # Try PATH first
    import shutil
    found = shutil.which("maestro")
    if found:
        return found
    # Common install location on Windows
    home_bin = os.path.expanduser("~/.maestro/bin/maestro")
    if os.path.exists(home_bin):
        return home_bin
    return "maestro"  # Fall back, let subprocess raise the error


def run_maestro(
    flow_path: str,
    env_vars: dict[str, str] | None = None,
    timeout_seconds: float = 180,
) -> int:
    """Run a Maestro flow as a subprocess. Returns exit code; 124 on
    timeout.

    The hard timeout is a watchdog: a wedged Maestro daemon (e.g. a
    prior run killed mid-login) blocks the next `maestro test`
    indefinitely — observed holding the device for 83 minutes. Failing
    the attempt lets retry/exit logic run instead of hanging the lane.

    Passes env_vars to Maestro via --env flags so they're available
    in YAML flows as ${VAR_NAME}.
    """
    maestro_cmd = _find_maestro()
    cmd = [maestro_cmd, "test"]

    # Pass env vars via --env KEY=VALUE flags
    for key, val in (env_vars or {}).items():
        cmd.extend(["--env", f"{key}={val}"])

    cmd.append(flow_path)

    print(f"  Maestro: {os.path.basename(flow_path)}")
    # start_new_session: on POSIX the child gets its own process group —
    # without it, _kill_tree's killpg would target OUR group (suicide).
    # Ignored on Windows (taskkill /T path).
    proc = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        start_new_session=True,
    )
    try:
        stdout, _ = proc.communicate(timeout=timeout_seconds)
    except subprocess.TimeoutExpired:
        # Kill the TREE: a plain child-kill leaves the Maestro JVM
        # grandchild alive on Windows, re-wedging the device for every
        # following flow.
        _kill_tree(proc.pid)
        proc.communicate()  # drain pipes, reap
        print(f"    WATCHDOG: Maestro exceeded {timeout_seconds:.0f}s — "
              "process tree killed (wedged daemon?)")
        return 124
    if stdout:
        for line in stdout.strip().split("\n"):
            print(f"    {line}")
    return proc.returncode


def _kill_tree(pid: int) -> None:
    """Kill a process and all descendants (platform-aware)."""
    if sys.platform.startswith("win"):
        subprocess.run(
            ["taskkill", "/F", "/T", "/PID", str(pid)],
            capture_output=True,
        )
    else:
        import signal

        try:
            pgid = os.getpgid(pid)
            # Never kill our own group — if the child somehow shares it
            # (start_new_session missed), killpg here would be suicide.
            # getattr: SIGKILL is absent on Windows and this branch must
            # stay importable/testable there (value 9 on every POSIX).
            if pgid != os.getpgrp():
                os.killpg(pgid, getattr(signal, "SIGKILL", 9))
        except (ProcessLookupError, PermissionError):
            pass


def run_verify(
    log_path: str, scenario_name: str, scripts_path: str, tag: str
) -> int:
    """Run verify.py to check logcat results. Returns exit code."""
    cmd = [
        sys.executable,
        os.path.join(SCRIPT_DIR, "verify.py"),
        "--log", log_path,
        "--scenario", scenario_name,
        "--scripts", scripts_path,
        "--tag", tag,
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.stdout:
        for line in result.stdout.strip().split("\n"):
            print(f"    {line}")
    return result.returncode


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Orchestrate voice E2E tests — Maestro + audio + logcat"
    )
    parser.add_argument(
        "--scenario", required=True, help="Scenario name from test-scripts.json"
    )
    parser.add_argument(
        "--scripts", required=True, help="Path to test-scripts.json"
    )
    parser.add_argument(
        "--wavs", required=True, help="Directory with generated WAV files"
    )
    parser.add_argument(
        "--flow", required=True, help="Path to Maestro YAML flow"
    )
    parser.add_argument(
        "--tag", default=None,
        help="Logcat tag (fallback: ACOUSTIC_TAG env var)",
    )
    parser.add_argument(
        "--timeout", type=float, default=60,
        help="Overall timeout in seconds (default: 60)",
    )
    parser.add_argument(
        "--env", action="append", default=[],
        help="Pass env var to Maestro (KEY=VALUE), repeatable",
    )
    parser.add_argument(
        "--retries", type=int, default=0,
        help="Re-run a failed attempt up to N times (over-air noise)",
    )
    args = parser.parse_args()

    # Resolve tag
    tag = args.tag or os.environ.get("ACOUSTIC_TAG")
    if not tag:
        print("ERROR: --tag or ACOUSTIC_TAG env var required")
        sys.exit(2)

    # Load scenario
    if not os.path.exists(args.scripts):
        print(f"ERROR: Scripts file not found: {args.scripts}")
        sys.exit(2)

    with open(args.scripts, "r", encoding="utf-8") as f:
        data = json.load(f)

    scenario = next(
        (s for s in data["scenarios"] if s["name"] == args.scenario), None
    )
    if not scenario:
        available = [s["name"] for s in data["scenarios"]]
        print(f"ERROR: Scenario '{args.scenario}' not found")
        print(f"Available: {', '.join(available)}")
        sys.exit(2)

    config = parse_scenario_config(scenario)
    log_path = os.path.join(os.path.dirname(args.scripts), "session.log")

    print(f"=== Orchestrating: {args.scenario} ===")
    print(f"  Flow type: {config['flow_type']}")
    print(f"  Trigger: {config['trigger_signal']}")
    print(f"  Tag: {tag}")
    print()

    # Pre-warm voice-note audio BEFORE the flow starts: trigger-time
    # subprocess startup loses the race against the app's STT listening
    # window. Daily-call paths keep the play.py subprocess (they also
    # monitor logcat and are not start-latency critical). Loaded once,
    # reused across retry attempts.
    preloaded_wavs: dict = {}
    if config["flow_type"] == "voice-note":
        for i, _ in enumerate(scenario["utterances"]):
            wav_name = f"{scenario['name']}_{i}.wav"
            wav_path = os.path.join(args.wavs, wav_name)
            if os.path.exists(wav_path):
                preloaded_wavs[wav_path] = PreloadedAudio(wav_path)
        if preloaded_wavs:
            print(f"  Pre-warmed {len(preloaded_wavs)} WAV(s)")

    attempt_no = {"n": 0}

    def attempt() -> int:
        attempt_no["n"] += 1
        return _run_attempt(args, config, scenario, tag, log_path,
                            preloaded_wavs, attempt_no["n"])

    sys.exit(run_with_retries(attempt, args.retries))


def _run_attempt(args, config, scenario, tag, log_path, preloaded_wavs,
                 attempt_no) -> int:
    # Step 1: Clear logcat
    subprocess.run(["adb", "logcat", "-c"], capture_output=True)
    print("  Logcat cleared")

    # Step 2: Set up trigger — play audio when signal detected
    audio_played = threading.Event()

    def on_trigger(line):
        print(f"  TRIGGER: {line.strip()}")
        for i, utterance in enumerate(scenario["utterances"]):
            wav_name = f"{scenario['name']}_{i}.wav"
            wav_path = os.path.join(args.wavs, wav_name)
            if not os.path.exists(wav_path):
                print(f"  ERROR: WAV not found: {wav_path}")
                continue
            play_audio(
                wav_path,
                play_only=(config["flow_type"] == "voice-note"),
                tag=tag,
                preloaded=preloaded_wavs.get(wav_path),
            )
        audio_played.set()

    trigger = LogcatTrigger(
        signal=config["trigger_signal"],
        tag=tag,
        callback=on_trigger,
    )

    # Step 3: Start logcat monitor
    stop_monitor = threading.Event()
    monitor_proc: dict = {}
    monitor_thread = threading.Thread(
        target=run_logcat_monitor,
        args=(tag, [trigger], log_path, stop_monitor, monitor_proc),
        daemon=True,
    )
    monitor_thread.start()
    print("  Logcat monitor started")
    print()

    # Step 4: Launch Maestro (blocks until flow completes)
    # Parse --env KEY=VALUE pairs into dict for Maestro
    maestro_env = {}
    for env_pair in args.env:
        if "=" in env_pair:
            k, v = env_pair.split("=", 1)
            maestro_env[k] = v
    maestro_exit = run_maestro(
        args.flow,
        env_vars=maestro_env if maestro_env else None,
        # Tight by default (owner policy): hang detection beats slack.
        # Loosen per-flow only with measured evidence.
        timeout_seconds=max(args.timeout * 2, 180),
    )
    print()

    # Step 5: Stop logcat monitor
    stop_monitor.set()
    # Kill the adb pipe FIRST: a quiet logcat leaves the thread blocked
    # in readline() past any join timeout, and a survivor poisons the
    # retry attempt.
    if monitor_proc.get("proc") is not None:
        try:
            monitor_proc["proc"].kill()
        except OSError:
            pass
    monitor_thread.join(timeout=5)

    # Step 6: Verify (daily call only)
    verify_exit = 0
    if config["needs_logcat_verify"]:
        print("--- Verification ---")
        verify_exit = run_verify(log_path, args.scenario, args.scripts, tag)
        print()

    # Step 7: Report
    print("=== Results ===")
    maestro_status = "PASS" if maestro_exit == 0 else "FAIL"
    print(f"  Maestro:  {maestro_status} (exit {maestro_exit})")
    if config["needs_logcat_verify"]:
        verify_status = "PASS" if verify_exit == 0 else "FAIL"
        print(f"  Verify:   {verify_status} (exit {verify_exit})")
    audio_status = "played" if audio_played.is_set() else "NOT played (trigger never fired)"
    print(f"  Audio:    {audio_status}")
    print(f"  Log:      {log_path}")

    overall = maestro_exit == 0 and verify_exit == 0 and audio_played.is_set()
    print(f"  Overall:  {'PASS' if overall else 'FAIL'}")

    if not overall:
        # Preserve evidence before a retry overwrites session.log.
        # Flow-prefixed: attempt numbering restarts per invocation; a
        # sweep would otherwise keep only the last failing flow's logs.
        flow_name = os.path.splitext(os.path.basename(args.flow))[0]
        fail_log = log_path.replace(
            ".log", f".{flow_name}.fail-{attempt_no}.log"
        )
        try:
            import shutil

            shutil.copyfile(log_path, fail_log)
            print(f"  Saved failure log: {fail_log}")
        except OSError:
            pass
    return 0 if overall else 1


if __name__ == "__main__":
    main()
