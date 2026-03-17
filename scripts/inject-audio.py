#!/usr/bin/env python3
"""Inject a WAV file into the Android emulator's virtual microphone via gRPC.

Uses the EmulatorController.injectAudio RPC from the Android Emulator gRPC API.
The emulator must be running. Discovery is automatic via pid_*.ini files.

Usage:
    python scripts/inject-audio.py <wav-file> [--realtime]

Requirements:
    pip install grpcio grpcio-tools

Proto stubs generated from:
    $ANDROID_SDK/emulator/lib/emulator_controller.proto
"""

import argparse
import glob
import os
import platform
import re
import sys
import time
import wave

import grpc

# Add grpc_gen to path for proto imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "grpc_gen"))

import emulator_controller_pb2 as pb2
import emulator_controller_pb2_grpc as pb2_grpc

# 300ms chunk size matches the emulator's internal audio buffer
CHUNK_DURATION_S = 0.3


def discover_emulator():
    """Find the running emulator's gRPC address and token.

    Searches platform-specific directories for pid_*.ini files created by
    the emulator at startup. Returns (address, token) tuple.
    """
    search_dirs = []

    if platform.system() == "Windows":
        local_app_data = os.environ.get("LOCALAPPDATA", "")
        if local_app_data:
            search_dirs.append(os.path.join(local_app_data, "Temp", "avd", "running"))
    else:
        xdg = os.environ.get("XDG_RUNTIME_DIR", "")
        if xdg:
            search_dirs.append(os.path.join(xdg, "avd", "running"))

    # Fallback: ~/.android/avd/running
    home = os.path.expanduser("~")
    search_dirs.append(os.path.join(home, ".android", "avd", "running"))

    for search_dir in search_dirs:
        pattern = os.path.join(search_dir, "pid_*.ini")
        for ini_path in glob.glob(pattern):
            address, token = _parse_ini(ini_path)
            if address:
                return address, token

    return None, None


def _parse_ini(path):
    """Parse a pid_*.ini file for grpc.address and grpc.token."""
    address = None
    token = None
    try:
        with open(path, "r") as f:
            for line in f:
                line = line.strip()
                if "=" in line:
                    idx = line.index("=")
                    key = line[:idx].strip()
                    value = line[idx + 1 :].strip()
                    if key == "grpc.address":
                        address = value
                    elif key == "grpc.token":
                        token = value
    except OSError:
        pass
    return address, token


def read_wav_chunks(wav_path, realtime=False):
    """Yield AudioPacket messages from a WAV file in 300ms chunks.

    The first packet includes the AudioFormat; subsequent packets omit it.
    """
    with wave.open(wav_path, "rb") as wf:
        sample_width = wf.getsampwidth()
        channels = wf.getnchannels()
        frame_rate = wf.getframerate()
        n_frames = wf.getnframes()

        # Map sample width to proto SampleFormat
        if sample_width == 1:
            sample_format = pb2.AudioFormat.AUD_FMT_U8
        elif sample_width == 2:
            sample_format = pb2.AudioFormat.AUD_FMT_S16
        else:
            raise ValueError(f"Unsupported sample width: {sample_width} bytes")

        # Map channels
        channel_enum = pb2.AudioFormat.Mono if channels == 1 else pb2.AudioFormat.Stereo

        fmt = pb2.AudioFormat(
            samplingRate=frame_rate,
            channels=channel_enum,
            format=sample_format,
            mode=pb2.AudioFormat.MODE_REAL_TIME if realtime else pb2.AudioFormat.MODE_UNSPECIFIED,
        )

        # Chunk size: 300ms of frames
        frame_size = sample_width * channels
        chunk_frames = int(frame_rate * CHUNK_DURATION_S)
        frames_read = 0
        first = True

        print(f"WAV: {frame_rate}Hz, {channels}ch, {sample_width * 8}-bit, {n_frames} frames ({n_frames / frame_rate:.1f}s)")

        while frames_read < n_frames:
            data = wf.readframes(chunk_frames)
            if not data:
                break

            timestamp = int(time.time() * 1_000_000)
            packet = pb2.AudioPacket(
                format=fmt if first else None,
                timestamp=timestamp,
                audio=data,
            )
            first = False
            frames_read += len(data) // frame_size

            yield packet

            if realtime:
                time.sleep(CHUNK_DURATION_S)


def inject(wav_path, realtime=False):
    """Inject a WAV file into the emulator's virtual microphone."""
    address, token = discover_emulator()
    if not address:
        print("ERROR: No running emulator found.")
        print("  Searched for pid_*.ini in:")
        if platform.system() == "Windows":
            print(f"    %LOCALAPPDATA%\\Temp\\avd\\running\\")
        print(f"    ~/.android/avd/running/")
        print("  Start an emulator and try again.")
        sys.exit(1)

    print(f"Emulator found at {address}")

    # Connect
    channel = grpc.insecure_channel(address)
    if token:
        # Attach token as call metadata
        metadata = [("authorization", f"Bearer {token}")]
        print(f"  Using auth token: {token[:8]}...")
    else:
        metadata = []
        print("  No auth token (insecure)")

    stub = pb2_grpc.EmulatorControllerStub(channel)

    # Stream audio packets
    audio_stream = read_wav_chunks(wav_path, realtime=realtime)

    print(f"Injecting audio from: {wav_path}")
    try:
        stub.injectAudio(audio_stream, metadata=metadata)
        print("Audio injection complete.")
    except grpc.RpcError as e:
        code = e.code()
        if code == grpc.StatusCode.FAILED_PRECONDITION:
            print(f"ERROR: Microphone already in use (another inject session active)")
        elif code == grpc.StatusCode.INVALID_ARGUMENT:
            print(f"ERROR: Invalid audio format or packet too large: {e.details()}")
        else:
            print(f"ERROR: gRPC error ({code}): {e.details()}")
        sys.exit(1)
    finally:
        channel.close()


def main():
    parser = argparse.ArgumentParser(
        description="Inject a WAV file into the Android emulator's virtual microphone via gRPC."
    )
    parser.add_argument("wav_file", help="Path to the WAV file to inject")
    parser.add_argument(
        "--realtime",
        action="store_true",
        help="Pace delivery at real-time speed (experimental MODE_REAL_TIME)",
    )
    args = parser.parse_args()

    if not os.path.isfile(args.wav_file):
        print(f"ERROR: WAV file not found: {args.wav_file}")
        sys.exit(1)

    inject(args.wav_file, realtime=args.realtime)


if __name__ == "__main__":
    main()
