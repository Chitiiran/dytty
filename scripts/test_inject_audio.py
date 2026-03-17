#!/usr/bin/env python3
"""Tests for inject-audio.py — WAV chunking and discovery logic.

Run: python -m pytest scripts/test_inject_audio.py -v
  or: python scripts/test_inject_audio.py
"""

import os
import struct
import sys
import tempfile
import wave

# Add scripts dir to path
sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "grpc_gen"))

# Import after path setup
from importlib import import_module

inject_audio = import_module("inject-audio")


def _make_wav(path, duration_s=1.0, sample_rate=16000, channels=1, sample_width=2):
    """Create a minimal WAV file for testing."""
    n_samples = int(sample_rate * duration_s)
    with wave.open(path, "w") as wf:
        wf.setnchannels(channels)
        wf.setsampwidth(sample_width)
        wf.setframerate(sample_rate)
        for i in range(n_samples):
            sample = i % 32767
            if sample_width == 1:
                wf.writeframes(struct.pack("B", sample % 256))
            else:
                wf.writeframes(struct.pack("<h", sample))


def test_read_wav_chunks_produces_packets():
    """read_wav_chunks yields AudioPacket objects with correct format."""
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        path = f.name

    try:
        _make_wav(path, duration_s=1.0, sample_rate=16000)
        packets = list(inject_audio.read_wav_chunks(path))

        assert len(packets) > 0, "Should produce at least one packet"

        # First packet has format
        first = packets[0]
        assert first.format.samplingRate == 16000
        assert first.format.channels == 0  # Mono = 0
        assert first.format.format == 1  # AUD_FMT_S16 = 1
        assert len(first.audio) > 0
    finally:
        os.unlink(path)


def test_chunk_count_for_1s_at_16khz():
    """1 second at 16kHz with 300ms chunks should produce ~4 packets."""
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        path = f.name

    try:
        _make_wav(path, duration_s=1.0, sample_rate=16000)
        packets = list(inject_audio.read_wav_chunks(path))
        # 1000ms / 300ms = 3.33 -> 4 chunks
        assert len(packets) == 4, f"Expected 4 chunks, got {len(packets)}"
    finally:
        os.unlink(path)


def test_chunk_count_for_3s():
    """3 seconds at 16kHz should produce ~10 packets."""
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        path = f.name

    try:
        _make_wav(path, duration_s=3.0, sample_rate=16000)
        packets = list(inject_audio.read_wav_chunks(path))
        # 3000ms / 300ms = 10 chunks
        assert len(packets) == 10, f"Expected 10 chunks, got {len(packets)}"
    finally:
        os.unlink(path)


def test_8bit_mono_format():
    """8-bit unsigned WAV should use AUD_FMT_U8."""
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        path = f.name

    try:
        _make_wav(path, duration_s=0.5, sample_rate=8000, sample_width=1)
        packets = list(inject_audio.read_wav_chunks(path))

        assert len(packets) > 0
        assert packets[0].format.format == 0  # AUD_FMT_U8
        assert packets[0].format.samplingRate == 8000
    finally:
        os.unlink(path)


def test_stereo_format():
    """Stereo WAV should use Channels.Stereo."""
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        path = f.name

    try:
        _make_wav(path, duration_s=0.5, sample_rate=44100, channels=2)
        packets = list(inject_audio.read_wav_chunks(path))

        assert len(packets) > 0
        assert packets[0].format.channels == 1  # Stereo = 1
        assert packets[0].format.samplingRate == 44100
    finally:
        os.unlink(path)


def test_only_first_packet_has_format():
    """Only the first packet should have format set."""
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        path = f.name

    try:
        _make_wav(path, duration_s=1.0, sample_rate=16000)
        packets = list(inject_audio.read_wav_chunks(path))

        assert len(packets) > 1
        # First has format
        assert packets[0].format.samplingRate == 16000
        # Subsequent should have no format (default empty)
        for p in packets[1:]:
            assert p.format.samplingRate == 0, "Later packets should not set format"
    finally:
        os.unlink(path)


def test_all_packets_have_audio_data():
    """Every packet should contain non-empty audio bytes."""
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        path = f.name

    try:
        _make_wav(path, duration_s=1.0, sample_rate=16000)
        packets = list(inject_audio.read_wav_chunks(path))

        for i, p in enumerate(packets):
            assert len(p.audio) > 0, f"Packet {i} has empty audio"
    finally:
        os.unlink(path)


def test_all_packets_have_timestamps():
    """Every packet should have a non-zero timestamp."""
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        path = f.name

    try:
        _make_wav(path, duration_s=0.5, sample_rate=16000)
        packets = list(inject_audio.read_wav_chunks(path))

        for i, p in enumerate(packets):
            assert p.timestamp > 0, f"Packet {i} has zero timestamp"
    finally:
        os.unlink(path)


def test_parse_ini_with_address_and_token():
    """_parse_ini should extract grpc.address and grpc.token."""
    with tempfile.NamedTemporaryFile(mode="w", suffix=".ini", delete=False) as f:
        f.write("grpc.address=localhost:8554\n")
        f.write("grpc.token=abc123\n")
        f.write("other.key=value\n")
        path = f.name

    try:
        address, token = inject_audio._parse_ini(path)
        assert address == "localhost:8554"
        assert token == "abc123"
    finally:
        os.unlink(path)


def test_parse_ini_missing_token():
    """_parse_ini should return None for missing token."""
    with tempfile.NamedTemporaryFile(mode="w", suffix=".ini", delete=False) as f:
        f.write("grpc.address=localhost:8554\n")
        path = f.name

    try:
        address, token = inject_audio._parse_ini(path)
        assert address == "localhost:8554"
        assert token is None
    finally:
        os.unlink(path)


def test_parse_ini_with_port_only():
    """_parse_ini should construct localhost address from grpc.port."""
    with tempfile.NamedTemporaryFile(mode="w", suffix=".ini", delete=False) as f:
        f.write("grpc.port=8554\n")
        f.write("grpc.token=xyz789\n")
        path = f.name

    try:
        address, token = inject_audio._parse_ini(path)
        assert address == "localhost:8554"
        assert token == "xyz789"
    finally:
        os.unlink(path)


def test_parse_ini_address_takes_precedence_over_port():
    """grpc.address should take precedence over grpc.port."""
    with tempfile.NamedTemporaryFile(mode="w", suffix=".ini", delete=False) as f:
        f.write("grpc.address=10.0.0.1:9090\n")
        f.write("grpc.port=8554\n")
        path = f.name

    try:
        address, token = inject_audio._parse_ini(path)
        assert address == "10.0.0.1:9090"
    finally:
        os.unlink(path)


def test_parse_ini_nonexistent_file():
    """_parse_ini should return (None, None) for missing file."""
    address, token = inject_audio._parse_ini("/nonexistent/pid_999.ini")
    assert address is None
    assert token is None


def test_existing_test_wavs():
    """Verify the committed test WAV files can be chunked."""
    fixtures_dir = os.path.join(os.path.dirname(__file__), "..", "test", "fixtures", "audio")

    for name in ["test-tone-440hz.wav", "test-tone-1khz.wav"]:
        path = os.path.join(fixtures_dir, name)
        if not os.path.exists(path):
            continue  # Skip if fixtures not present

        packets = list(inject_audio.read_wav_chunks(path))
        assert len(packets) > 0, f"{name}: should produce packets"
        assert packets[0].format.samplingRate == 16000, f"{name}: expected 16kHz"


if __name__ == "__main__":
    # Simple test runner without pytest dependency
    import traceback

    tests = [v for k, v in sorted(globals().items()) if k.startswith("test_")]
    passed = 0
    failed = 0

    for test_fn in tests:
        name = test_fn.__name__
        try:
            test_fn()
            print(f"  PASS  {name}")
            passed += 1
        except Exception as e:
            print(f"  FAIL  {name}: {e}")
            traceback.print_exc()
            failed += 1

    print(f"\n{passed} passed, {failed} failed, {passed + failed} total")
    sys.exit(1 if failed else 0)
