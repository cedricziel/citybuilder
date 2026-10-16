"""The original music: a score language that adds up, an in-tune band, and
committed renders that match their scores byte for byte."""

from __future__ import annotations

import numpy as np
import pytest

from audio import dsp
from audio.music import pieces, render, score, synth


def _pitch(signal: np.ndarray) -> float:
    """Fundamental by autocorrelation with a parabolic peak."""
    x = signal[2000:12000] - signal[2000:12000].mean()
    ac = np.correlate(x, x, "full")[len(x) - 1 :]
    lo, hi = synth.SR // 1000, synth.SR // 60
    p = lo + int(np.argmax(ac[lo:hi]))
    a, b, c = ac[p - 1], ac[p], ac[p + 1]
    return synth.SR / (p + 0.5 * (a - c) / (a - 2 * b + c))


def test_note_names():
    assert score.midi("a4") == 69
    assert score.midi("f#4") == 66
    assert score.midi("bb3") == 58
    assert abs(score.hz(69) - 440.0) < 1e-9
    assert abs(score.hz(81) - 880.0) < 1e-9
    assert score.chord_tones("Dm") == [50, 53, 57]
    assert score.chord_tones("G") == [55, 59, 62]


@pytest.mark.parametrize("freq", [98.0, 146.83, 293.66, 587.33, 880.0])
def test_plucked_strings_are_in_tune(freq):
    cents = 1200 * np.log2(_pitch(synth.pluck(freq, 1.0, 1.0, 0.5, dsp.Rng(1))) / freq)
    assert abs(cents) < 3


@pytest.mark.parametrize("piece", pieces.PIECES, ids=lambda p: p.title)
def test_every_melody_fills_its_bars(piece):
    for section in piece.sections:
        if section.melody:
            beats = sum(float(token.split(":")[1]) for token in section.melody.split())
            assert beats == len(section.chords.split()) * piece.beats_per_bar, section.chords


def test_pieces_fit_the_size_cap():
    for piece in pieces.PIECES:
        bars = sum(len(s.chords.split()) for s in piece.sections)
        seconds = bars * piece.beats_per_bar * 60 / piece.bpm + 4
        assert seconds * synth.SR / 64 * 34 < 3_000_000, piece.title  # pre-commit caps files at 3 MB


@pytest.mark.scenario("Regenerating reproduces the committed music")
def test_committed_music_matches_its_scores():
    assert render.main(["--check"]) == 0
