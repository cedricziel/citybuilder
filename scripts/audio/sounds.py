"""Recipes for the game's procedural sounds.

Each recipe returns mono samples at its sample rate. Loops are periodic:
events are scheduled into a buffer of the loop's length and their tails
wrap around to the start, so the end flows into the beginning.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Callable

from audio import dsp

SR = 44100  # every sound renders at this rate

# Loudness targets per bus, as linear RMS. One-shots are measured over their
# loudest 50 ms, loops and beds over their whole length, so a coin and a
# chime sound equally loud, and every workshop sits at one level under them.
LEVELS = {"sfx": 0.22, "loop": 0.10, "ambient": 0.06}


@dataclass(frozen=True)
class Sound:
    path: str
    title: str
    bus: str
    render: Callable[[], list[float]]


def room(signal: list[float], sr: int, wrap: bool = False, wet: float = 0.35) -> list[float]:
    """A small timber room: a handful of early reflections, darker as they arrive later."""
    out = list(signal)
    for delay, gain in ((0.019, 0.5), (0.031, 0.38), (0.047, 0.3), (0.067, 0.22), (0.089, 0.15)):
        echo = dsp.lowpass(signal, 5000 - delay * 30000, sr)
        dsp.mix_into(out, echo, int(delay * sr), wet * gain, wrap=wrap)
    return out


def wood_knock(sr: int, pitch: float, rng: dsp.Rng, length: float = 0.25) -> list[float]:
    """A mallet or axe on timber: a short noise click exciting a few inharmonic body modes."""
    n = int(length * sr)
    click = dsp.mul(dsp.highpass(dsp.white(n, rng), 1500, sr), dsp.decay_env(n, 0.0005, 0.004, sr))
    body = dsp.silence(n)
    for ratio, decay, amp in ((1.0, 0.07, 1.0), (2.32, 0.04, 0.55), (4.1, 0.025, 0.3), (6.7, 0.015, 0.15)):
        dsp.mix_into(body, dsp.mode(n, pitch * ratio * rng.uniform(0.98, 1.02), decay, sr, amp), 0)
    return [c * 0.6 + b for c, b in zip(click, body)]


def saw_stroke(sr: int, length: float, brightness: float, rng: dsp.Rng) -> list[float]:
    """One pull of a frame saw: rasping teeth over a wooden body, swelling and fading."""
    n = int(length * sr)
    noise = dsp.white(n, rng)
    rasp = dsp.bandpass(noise, 2400 * brightness, 1.1, sr)
    body = dsp.bandpass(noise, 520, 2.0, sr)
    out = []
    for i in range(n):
        t = i / n
        swell = dsp.sin_turns(t / 2)  # 0 → 1 → 0 over the stroke
        teeth = 0.55 + 0.45 * abs(dsp.sin_turns(i * 38 / sr))
        out.append(swell * swell * teeth * (rasp[i] * 1.4 + body[i] * 0.8))
    return out


def sawmill() -> list[float]:
    rng = dsp.Rng(11)
    n = int(3.0 * SR)
    out = dsp.silence(n)
    for k, start in enumerate((0.0, 0.75, 1.5, 2.25)):
        stroke = saw_stroke(SR, 0.72, 1.12 if k % 2 == 0 else 0.92, rng)
        dsp.mix_into(out, stroke, int(start * SR), 1.0 if k % 2 == 0 else 0.8, wrap=True)
    return room(out, SR, wrap=True, wet=0.25)


def lumberjack() -> list[float]:
    rng = dsp.Rng(23)
    n = int(3.0 * SR)
    out = dsp.silence(n)
    for start, pitch, gain in ((0.1, 190.0, 1.0), (1.55, 175.0, 0.85)):
        dsp.mix_into(out, wood_knock(SR, pitch, rng, 0.4), int(start * SR), gain, wrap=True)
        # The blade working loose: a quieter, higher knock just after.
        dsp.mix_into(out, wood_knock(SR, pitch * 2.6, rng, 0.15), int((start + 0.09) * SR), 0.18 * gain, wrap=True)
    return room(out, SR, wrap=True, wet=0.45)


def carrier_clink() -> list[float]:
    rng = dsp.Rng(31)
    n = int(0.35 * SR)
    out = dsp.silence(n)
    for at, gain in ((0.0, 1.0), (0.07, 0.55)):
        tap = wood_knock(SR, 610 * rng.uniform(0.95, 1.05), rng, 0.2)
        dsp.mix_into(tap, dsp.mode(len(tap), 2150, 0.05, SR, 0.25), 0)
        dsp.mix_into(out, tap, int(at * SR), gain)
    return dsp.fade_edges(room(out, SR), 0.0005, 0.03, SR)


def chirp(sr: int, start_hz: float, end_hz: float, length: float, vibrato: float = 0.0) -> list[float]:
    """One bird syllable: a pure tone gliding between two pitches with a soft envelope."""
    n = int(length * sr)
    phase = 0.0
    out = []
    for i in range(n):
        t = i / n
        freq = start_hz + (end_hz - start_hz) * t + vibrato * dsp.sin_turns(i * 30 / sr)
        phase += freq / sr
        env = dsp.sin_turns(t / 2)
        out.append(env * env * dsp.sin_turns(phase))
    return out


def forest_birds() -> list[float]:
    """A spring wood: leaves stirring under scattered song from three kinds of bird."""
    rng = dsp.Rng(47)
    sr = SR
    n = int(16.0 * sr)
    breeze = dsp.lowpass(dsp.lowpass(dsp.lowpass(dsp.white(n + sr, rng), 700, sr), 900, sr), 1200, sr)
    swell = [0.6 + 0.4 * dsp.sin_turns(i / (n + sr) * 2) for i in range(n + sr)]
    out = dsp.scale(dsp.loop_crossfade(dsp.mul(breeze, swell), n), 2.0)
    t = 0.3
    while t < 16.0:
        kind = rng.next_u64() % 3
        at = int(t * sr)
        gain = rng.uniform(0.25, 0.6)
        if kind == 0:  # trill: a quick run of falling notes
            base = rng.uniform(3600, 4600)
            for k in range(int(rng.uniform(5, 10))):
                dsp.mix_into(out, chirp(sr, base, base * 0.8, 0.045), at + int(k * 0.06 * sr), gain, wrap=True)
        elif kind == 1:  # whistle: two long glides, up then down
            base = rng.uniform(2200, 2900)
            dsp.mix_into(out, chirp(sr, base, base * 1.35, 0.22, 40), at, gain, wrap=True)
            dsp.mix_into(out, chirp(sr, base * 1.3, base * 0.95, 0.3, 40), at + int(0.3 * sr), gain * 0.8, wrap=True)
        else:  # warble: short notes hopping around
            for k in range(int(rng.uniform(3, 6))):
                hz = rng.uniform(2600, 4200)
                dsp.mix_into(out, chirp(sr, hz, hz * rng.uniform(0.85, 1.2), 0.08, 120), at + int(k * 0.11 * sr), gain, wrap=True)
        t += rng.uniform(0.7, 2.2)
    return out


SOUNDS = [
    Sound("loop/sawmill.caf", "Sawmill: frame saw", "loop", sawmill),
    Sound("loop/lumberjack.caf", "Lumberjack: axe on timber", "loop", lumberjack),
    Sound("sfx/carrier-clink.caf", "Carrier sets goods down", "sfx", carrier_clink),
    Sound("ambient/forest-birds.caf", "Spring wood with birdsong", "ambient", forest_birds),
]


def render(sound: Sound) -> list[float]:
    signal = sound.render()
    if sound.bus == "sfx":
        measured = dsp.loudest_window_rms(signal, SR // 20)
    else:
        measured = dsp.rms(signal)
    return dsp.normalise(signal, LEVELS[sound.bus], measured)
