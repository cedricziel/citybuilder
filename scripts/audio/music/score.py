"""A small score language and the arranger that turns it into audio.

A piece is a list of sections. Each section names a chord per bar
(`"Dm C Dm Am"`), a melody as `note:beats` tokens (`"d5:1 e5:.5 r:1"`,
sharps `f#5`, flats `bb4`), the instrument that leads, and which
accompaniment parts play. Timing and velocity are humanised with a
seeded random-number generator, so every render is the same.
"""

from __future__ import annotations

from dataclasses import dataclass, field

import numpy as np

from audio import dsp
from audio.music import synth

NOTE_OFFSETS = {"c": 0, "d": 2, "e": 4, "f": 5, "g": 7, "a": 9, "b": 11}
LEADS = {"recorder": synth.recorder, "lute": synth.lute, "harp": synth.harp}


def midi(name: str) -> int:
    """`"f#4"` → 66."""
    letter, rest = name[0].lower(), name[1:]
    shift = 0
    while rest and rest[0] in "#b":
        shift += 1 if rest[0] == "#" else -1
        rest = rest[1:]
    return 12 * (int(rest) + 1) + NOTE_OFFSETS[letter] + shift


def hz(note: int) -> float:
    """Equal temperament from A4 = 440 Hz, via our own exponential."""
    return 440.0 * dsp.exp((note - 69) * 0.057762265046662105)  # ln 2 / 12


def chord_tones(symbol: str) -> list[int]:
    """Root-position triad, root in octave 3: `"Dm"` → [50, 53, 57]."""
    minor = symbol.endswith("m")
    root = midi(symbol.rstrip("m") + "3")
    return [root, root + (3 if minor else 4), root + 7]


@dataclass(frozen=True)
class Section:
    chords: str
    melody: str = ""
    lead: str = "recorder"
    parts: tuple[str, ...] = ("harp",)
    octave: int = 0  # shifts the melody by octaves


@dataclass(frozen=True)
class Piece:
    path: str
    title: str
    bpm: float
    beats_per_bar: int
    tonic: str  # the drone's note, e.g. "d3"
    seed: int
    sections: list[Section] = field(default_factory=list)


class Arranger:
    def __init__(self, piece: Piece) -> None:
        self.piece = piece
        self.rng = dsp.Rng(piece.seed)
        self.beat = 60.0 / piece.bpm
        bars = sum(len(s.chords.split()) for s in piece.sections)
        self.length = int((bars * piece.beats_per_bar * self.beat + 4.0) * synth.SR)
        self.mix = np.zeros(self.length)

    def humanise(self, seconds: float) -> int:
        # The sum of three uniforms: a soft bell curve about ±15 ms wide.
        jitter = (self.rng.uniform(-1, 1) + self.rng.uniform(-1, 1) + self.rng.uniform(-1, 1)) * 0.005
        return max(0, int((seconds + jitter) * synth.SR))

    def add(self, sound: np.ndarray, at: float, gain: float) -> None:
        start = self.humanise(at)
        end = min(self.length, start + len(sound))
        if end > start:
            self.mix[start:end] = self.mix[start:end] + sound[: end - start] * gain

    def velocity(self, accent: bool) -> float:
        return self.rng.uniform(0.82, 0.95) if accent else self.rng.uniform(0.62, 0.8)

    def render(self) -> np.ndarray:
        t = 0.0
        for section in self.piece.sections:
            chords = section.chords.split()
            for part in section.parts:
                self.accompany(part, chords, t)
            self.lead(section, t)
            t += len(chords) * self.piece.beats_per_bar * self.beat
        return synth.hall(self.mix)

    def lead(self, section: Section, start: float) -> None:
        voice = LEADS[section.lead]
        at = start
        for token in section.melody.split():
            name, beats = token.split(":")
            length = float(beats) * self.beat
            if name != "r":
                note = midi(name) + 12 * section.octave
                accent = abs((at - start) / self.beat % self.piece.beats_per_bar) < 1e-6
                held = min(length * 1.05 + (0.6 if section.lead != "recorder" else 0.0), 3.0)
                self.add(voice(hz(note), held, self.velocity(accent), self.rng), at, 1.0)
            at += length

    def accompany(self, part: str, chords: list[str], start: float) -> None:
        bar = self.piece.beats_per_bar * self.beat
        if part == "drone":
            seconds = len(chords) * bar + 1.0
            tonic = midi(self.piece.tonic)
            for note in (tonic, tonic + 7):
                self.add(synth.drone(hz(note), seconds, 0.9, self.rng), start, 1.0)
            return
        for index, symbol in enumerate(chords):
            at = start + index * bar
            tones = chord_tones(symbol)
            if part == "harp":  # a chord rolled upward from the bass
                for k, note in enumerate([tones[0] - 12, *tones, tones[0] + 12]):
                    self.add(synth.harp(hz(note), 2.6, self.velocity(k == 0) * 0.7, self.rng), at + k * 0.035, 0.55)
            elif part == "lute":  # broken chord in eighths
                pattern = [tones[0] - 12, tones[2], tones[1] + 12, tones[2]] * self.piece.beats_per_bar
                for k, note in enumerate(pattern[: 2 * self.piece.beats_per_bar]):
                    self.add(synth.lute(hz(note), 1.2, self.velocity(k == 0) * 0.75, self.rng), at + k * self.beat / 2, 0.5)
            elif part == "drum":
                for b in range(self.piece.beats_per_bar):
                    deep = b == 0 or (self.piece.beats_per_bar == 4 and b == 2)
                    hit = synth.frame_drum(0.5 if deep else 0.15, self.velocity(deep), not deep, self.rng)
                    self.add(hit, at + b * self.beat, 0.7 if deep else 0.35)
            else:
                raise ValueError(f"unknown part {part}")


def render(piece: Piece) -> list[float]:
    """The piece as samples, faded at the ends and normalised for the music bus."""
    signal = Arranger(piece).render().tolist()
    signal = dsp.fade_edges(signal, 0.02, 3.0, synth.SR)
    return dsp.normalise(signal, 0.12, dsp.rms(signal))
