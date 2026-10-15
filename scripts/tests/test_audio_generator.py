"""The procedural sound generator: deterministic maths, a faithful IMA4 encoder,
and committed sounds that match their recipes byte for byte."""

from __future__ import annotations

import math
import struct

import pytest

from audio import caf, dsp, generate, sounds

RNG_SEED_1 = [9250730233835055965, 436590262223502864, 13834798903570954988]


def decode_ima4(data: bytes, frames: int) -> list[int]:
    """Apple's decoding, used by the tests to check the encoder round-trips."""
    out: list[int] = []
    predictor = 0
    for start in range(0, len(data), caf.BYTES_PER_PACKET):
        header = struct.unpack(">H", data[start : start + 2])[0]
        if (predictor & 0xFF80) != header & 0xFF80:
            predictor = header & 0xFF80
            if predictor >= 0x8000:
                predictor -= 0x10000
        index = header & 0x7F
        for byte in data[start + 2 : start + caf.BYTES_PER_PACKET]:
            for code in (byte & 0x0F, byte >> 4):
                step = caf.STEPS[index]
                delta = step >> 3
                if code & 4:
                    delta += step
                if code & 2:
                    delta += step >> 1
                if code & 1:
                    delta += step >> 2
                predictor = predictor - delta if code & 8 else predictor + delta
                predictor = max(-32768, min(32767, predictor))
                index = max(0, min(88, index + caf.INDEX_SHIFT[code & 7]))
                out.append(predictor)
    return out[:frames]


def test_sine_matches_libm_closely():
    for i in range(-400, 400):
        turns = i / 97
        assert abs(dsp.sin_turns(turns) - math.sin(2 * math.pi * turns)) < 2e-7


def test_exp_matches_libm_closely():
    for i in range(-300, 60):
        x = i / 7
        assert abs(dsp.exp(x) - math.exp(x)) <= 1e-12 * max(1.0, math.exp(x))


def test_rng_sequence_is_fixed():
    rng = dsp.Rng(1)
    assert [rng.next_u64() for _ in range(3)] == RNG_SEED_1


def test_ima4_round_trip_tracks_the_signal():
    signal = [0.6 * dsp.sin_turns(i * 440 / 44100) for i in range(4410)]
    pcm = caf.to_pcm16(signal)
    payload = caf.encode_ima4(pcm)
    assert len(payload) % caf.BYTES_PER_PACKET == 0
    decoded = decode_ima4(payload, len(pcm))
    worst = max(abs(a - b) for a, b in zip(pcm[256:], decoded[256:]))
    assert worst < 1200, worst  # IMA4 tracks a full-scale sine within a few percent


def test_caf_header_describes_mono_ima4():
    data = caf.write_caf([0.0] * 100, 22050)
    assert data[:4] == b"caff"
    assert data[8:12] == b"desc"
    rate, fmt, _, bpp, fpp, channels, _ = struct.unpack(">dIIIIII", data[20:52])
    assert (rate, fmt.to_bytes(4, "big"), bpp, fpp, channels) == (22050.0, b"ima4", 34, 64, 1)


def test_every_sound_is_audible_and_within_full_scale():
    for sound in sounds.SOUNDS:
        signal = sounds.render(sound)
        assert max(abs(x) for x in signal) <= 0.95
        assert dsp.rms(signal) > 0.01, sound.path


@pytest.mark.scenario("Regenerating reproduces the committed sounds")
def test_committed_sounds_match_their_recipes():
    assert generate.main(["--check"]) == 0


@pytest.mark.scenario("A stale sound fails the check")
def test_a_changed_recipe_fails_the_check(monkeypatch, capsys):
    original = sounds.SOUNDS[0]
    louder = sounds.Sound(original.path, original.title, original.bus,
                          lambda: [x * 0.5 for x in original.render()][::-1])
    monkeypatch.setattr(sounds, "SOUNDS", [louder])
    assert generate.main(["--check"]) == 1
    assert original.path in capsys.readouterr().err


def test_soft_clip_is_monotonic_and_continuous():
    ceiling, knee = 0.95, 0.76
    xs = [i / 1000 for i in range(-3000, 3001)]
    ys = [dsp.soft_clip(x, ceiling, knee) for x in xs]
    assert all(b >= a for a, b in zip(ys, ys[1:]))
    assert all(abs(b - a) <= 0.0011 for a, b in zip(ys, ys[1:]))  # no jumps, slope at most 1
    assert max(abs(y) for y in ys) <= ceiling
    assert dsp.soft_clip(0.5, ceiling, knee) == 0.5


def test_loudest_window_checks_every_offset():
    # A burst that straddles two half-window steps is still found whole.
    signal = [0.0] * 1000
    for i in range(325, 425):
        signal[i] = 1.0
    assert abs(dsp.loudest_window_rms(signal, 100) - 1.0) < 1e-9
