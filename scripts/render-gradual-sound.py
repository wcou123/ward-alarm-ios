#!/usr/bin/env python3
"""Render BeutAlarm's 60-second crescendo into the system alarm WAV.

The app and AlarmKit use the same PCM file. No runtime fade timer or background
audio session is necessary for the system sound's authored volume envelope.
"""

from array import array
from pathlib import Path
import argparse
import hashlib
import json
import math
import sys
import wave

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "scripts/windows-alarm-source.wav"
DESTINATION = ROOT / "WardAlarm/crescendo-alarm.wav"
SOURCE_SHA256 = "46c758f03534be1a2247413e7e5d92bcfdae1986f8f7f9fcaeabd3a72d131a2b"
RAMP_SECONDS = 60
TOTAL_SECONDS = 60
START_GAIN = 0.01


def make_sound():
    if hashlib.sha256(SOURCE.read_bytes()).hexdigest() != SOURCE_SHA256:
        raise ValueError("The original Windows source has changed")
    with wave.open(str(SOURCE), "rb") as source:
        channels = source.getnchannels()
        sample_rate = source.getframerate()
        sample_width = source.getsampwidth()
        original_frames = source.getnframes()
        if sample_width != 2 or source.getcomptype() != "NONE":
            raise ValueError("Expected uncompressed 16-bit PCM source")
        pcm = source.readframes(original_frames)

    total_frames = sample_rate * TOTAL_SECONDS
    byte_count = total_frames * channels * sample_width
    repetitions = (byte_count + len(pcm) - 1) // len(pcm)
    baseline = array("h")
    baseline.frombytes((pcm * repetitions)[:byte_count])
    if sys.byteorder != "little":
        baseline.byteswap()
    output = array("h", baseline)

    ramp_frames = sample_rate * RAMP_SECONDS
    for frame in range(ramp_frames):
        # A constant increase in decibels sounds smoother than a linear
        # sample-amplitude increase. Reach the unmodified source at exactly 60s.
        gain = START_GAIN ** (1 - frame / ramp_frames)
        first = frame * channels
        for channel in range(channels):
            index = first + channel
            output[index] = round(baseline[index] * gain)

    return output, baseline, channels, sample_rate, original_frames


def verify():
    expected, baseline, channels, sample_rate, original_frames = make_sound()
    with wave.open(str(DESTINATION), "rb") as rendered:
        if (rendered.getnchannels(), rendered.getsampwidth(), rendered.getframerate(), rendered.getnframes()) != (channels, 2, sample_rate, sample_rate * TOTAL_SECONDS):
            raise ValueError("Rendered WAV format or duration is incorrect")
        actual = array("h")
        actual.frombytes(rendered.readframes(rendered.getnframes()))
    if sys.byteorder != "little":
        actual.byteswap()
    # Permit one PCM least-significant bit for platform libm rounding.
    if any(abs(delivered - reference) > 1 for delivered, reference in zip(actual, expected)):
        raise ValueError("Rendered samples do not match the authored envelope")
    if max(abs(value) for value in actual) > max(abs(value) for value in baseline):
        raise ValueError("Rendering unexpectedly increased the source peak")
    report = {
        "ramp_seconds": RAMP_SECONDS,
        "total_seconds": TOTAL_SECONDS,
        "starting_gain": START_GAIN,
        "full_strength_after_seconds": RAMP_SECONDS,
        "gain_at_seconds": {str(t): round(START_GAIN ** (1 - min(t, RAMP_SECONDS) / RAMP_SECONDS), 6) for t in (0, 15, 30, 45, 60)},
        "sha256": hashlib.sha256(DESTINATION.read_bytes()).hexdigest(),
        "sample_rate": sample_rate,
        "channels": channels,
        "original_frames": original_frames,
        "every_sample_verified": True,
        "physical_AlarmKit_test_required": True,
    }
    print(json.dumps(report))


def render():
    samples, _, channels, sample_rate, _ = make_sound()
    if sys.byteorder != "little":
        samples.byteswap()
    with wave.open(str(DESTINATION), "wb") as rendered:
        rendered.setnchannels(channels)
        rendered.setsampwidth(2)
        rendered.setframerate(sample_rate)
        rendered.writeframes(samples.tobytes())
    verify()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--verify", action="store_true")
    if parser.parse_args().verify:
        verify()
    else:
        render()
