"""Deterministic DSP building blocks for the procedural sound generator.

Every function here uses only IEEE-754 basic arithmetic (+, -, *, /, sqrt)
in a fixed order, plus our own polynomial sine and exponential. `math.sin`
and friends come from the platform's libm and may differ in the last bit
between macOS and Linux, which would break the byte-for-byte regeneration
check. Signals are plain lists of floats in [-1, 1].
"""

from __future__ import annotations

import math

TAU = 6.283185307179586
LN2 = 0.6931471805599453


def sin_turns(turns: float) -> float:
    """sin(2π · turns), accurate to about 1e-7."""
    x = turns - math.floor(turns + 0.5)  # [-0.5, 0.5)
    if x > 0.25:
        x = 0.5 - x
    elif x < -0.25:
        x = -0.5 - x
    y = TAU * x  # |y| <= π/2
    y2 = y * y
    return y * (1 - y2 / 6 * (1 - y2 / 20 * (1 - y2 / 42 * (1 - y2 / 72 * (1 - y2 / 110 * (1 - y2 / 156))))))


def cos_turns(turns: float) -> float:
    return sin_turns(turns + 0.25)


def exp(x: float) -> float:
    """e^x for x in about [-700, 700], accurate to about 1e-12."""
    k = math.floor(x / LN2)
    f = x - k * LN2  # [0, ln 2)
    term = 1.0
    total = 1.0
    for n in range(1, 16):
        term = term * f / n
        total += term
    return math.ldexp(total, int(k))


def tanh(x: float) -> float:
    """Soft clipper: a Padé tanh, exact at the ends of [-3, 3] and clamped beyond."""
    if x >= 3:
        return 1.0
    if x <= -3:
        return -1.0
    x2 = x * x
    return x * (27 + x2) / (27 + 9 * x2)


class Rng:
    """xorshift64*: the same sequence on every platform and Python version."""

    def __init__(self, seed: int) -> None:
        self.state = (seed * 0x9E3779B97F4A7C15 + 1) & 0xFFFFFFFFFFFFFFFF

    def next_u64(self) -> int:
        s = self.state
        s ^= s >> 12
        s ^= (s << 25) & 0xFFFFFFFFFFFFFFFF
        s ^= s >> 27
        self.state = s
        return (s * 0x2545F4914F6CDD1D) & 0xFFFFFFFFFFFFFFFF

    def uniform(self, low: float = 0.0, high: float = 1.0) -> float:
        return low + (high - low) * ((self.next_u64() >> 11) / 9007199254740992.0)

    def noise(self) -> float:
        return self.uniform(-1.0, 1.0)


def silence(n: int) -> list[float]:
    return [0.0] * n


def white(n: int, rng: Rng) -> list[float]:
    return [rng.noise() for _ in range(n)]


def onepole_coeff(cutoff: float, sr: int) -> float:
    return 1 - exp(-TAU * cutoff / sr)


def lowpass(signal: list[float], cutoff: float, sr: int) -> list[float]:
    a = onepole_coeff(cutoff, sr)
    out = []
    y = 0.0
    for x in signal:
        y += a * (x - y)
        out.append(y)
    return out


def highpass(signal: list[float], cutoff: float, sr: int) -> list[float]:
    low = lowpass(signal, cutoff, sr)
    return [x - lo for x, lo in zip(signal, low)]


def bandpass(signal: list[float], centre: float, q: float, sr: int) -> list[float]:
    """RBJ constant-peak bandpass biquad."""
    w = centre / sr
    alpha = sin_turns(w) / (2 * q)
    cw = cos_turns(w)
    a0 = 1 + alpha
    b0, b2 = alpha / a0, -alpha / a0
    a1, a2 = -2 * cw / a0, (1 - alpha) / a0
    x1 = x2 = y1 = y2 = 0.0
    out = []
    for x in signal:
        y = b0 * x + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1 = x1, x
        y2, y1 = y1, y
        out.append(y)
    return out


def mode(n: int, freq: float, decay: float, sr: int, amp: float = 1.0, phase: float = 0.0) -> list[float]:
    """A struck resonance: a sine at `freq` Hz decaying by 1/e every `decay` seconds."""
    step = exp(-1 / (decay * sr))
    env = amp
    out = []
    for i in range(n):
        out.append(env * sin_turns(phase + freq * i / sr))
        env *= step
    return out


def decay_env(n: int, attack: float, decay: float, sr: int) -> list[float]:
    """Linear attack over `attack` seconds, then exponential decay."""
    attack_n = max(1, int(attack * sr))
    step = exp(-1 / (decay * sr))
    out = []
    level = 1.0
    for i in range(n):
        if i < attack_n:
            out.append(i / attack_n)
        else:
            out.append(level)
            level *= step
    return out


def mul(a: list[float], b: list[float]) -> list[float]:
    return [x * y for x, y in zip(a, b)]


def scale(signal: list[float], gain: float) -> list[float]:
    return [x * gain for x in signal]


def mix_into(target: list[float], signal: list[float], at: int, gain: float = 1.0, wrap: bool = False) -> None:
    """Adds `signal` into `target` from sample `at`; with `wrap` the tail continues at the start."""
    n = len(target)
    for i, x in enumerate(signal):
        j = at + i
        if j >= n:
            if not wrap:
                break
            j %= n
        target[j] += x * gain


def fade_edges(signal: list[float], fade_in: float, fade_out: float, sr: int) -> list[float]:
    n = len(signal)
    fin, fout = max(1, int(fade_in * sr)), max(1, int(fade_out * sr))
    out = list(signal)
    for i in range(min(fin, n)):
        out[i] *= i / fin
    for i in range(min(fout, n)):
        out[n - 1 - i] *= i / fout
    return out


def loop_crossfade(signal: list[float], length: int) -> list[float]:
    """Folds a render of `length + f` samples into a seamless loop of `length`."""
    tail = len(signal) - length
    out = signal[:length]
    for i in range(tail):
        t = i / tail
        out[i] = out[i] * t + signal[length + i] * (1 - t)
    return out


def rms(signal: list[float]) -> float:
    # An explicit loop: the built-in sum() compensates rounding from Python
    # 3.12 on, so it gives different bits on different interpreters.
    total = 0.0
    for x in signal:
        total += x * x
    return math.sqrt(total / len(signal)) if signal else 0.0


def loudest_window_rms(signal: list[float], window: int) -> float:
    """RMS of the loudest `window`-sample stretch: a one-shot's perceived level."""
    best = 0.0
    for start in range(0, max(1, len(signal) - window + 1), window // 2):
        best = max(best, rms(signal[start : start + window]))
    return best


def normalise(signal: list[float], level: float, measured: float, ceiling: float = 0.95) -> list[float]:
    """Scales so `measured` becomes `level`, soft-clipping anything above `ceiling`."""
    gain = level / measured if measured > 0 else 0.0
    out = []
    for x in signal:
        y = x * gain
        if y > ceiling or y < -ceiling:
            y = ceiling * tanh(y / ceiling)
        out.append(y)
    return out
