"""The band: plucked lute and harp, recorder, hurdy-gurdy drone and frame drum.

Arrays are numpy float64, but only elementwise +, -, *, / and our own
polynomial sine are used, never numpy's transcendental functions or
reductions, so the bytes are the same on every machine. Recursive
filters run in plain Python or in blocks no shorter than their delay,
which computes exactly what a sample-by-sample loop would.
"""

from __future__ import annotations

import numpy as np

from audio import dsp

SR = 32000
TAU = dsp.TAU


def sin_turns(turns: np.ndarray) -> np.ndarray:
    """sin(2π · turns) elementwise: the same polynomial as `dsp.sin_turns`."""
    x = turns - np.floor(turns + 0.5)
    x = np.where(x > 0.25, 0.5 - x, np.where(x < -0.25, -0.5 - x, x))
    y = TAU * x
    y2 = y * y
    return y * (1 - y2 / 6 * (1 - y2 / 20 * (1 - y2 / 42 * (1 - y2 / 72 * (1 - y2 / 110 * (1 - y2 / 156))))))


def decay(n: int, seconds: float) -> np.ndarray:
    """exp(-t / seconds) for n samples, built by repeated multiplication."""
    step = dsp.exp(-1 / (seconds * SR))
    out = np.empty(n)
    level = 1.0
    for i in range(n):
        out[i] = level
        level *= step
    return out


def envelope(n: int, attack: float, release: float) -> np.ndarray:
    """Linear attack and release around a flat middle."""
    env = np.ones(n)
    a = min(n, max(1, int(attack * SR)))
    r = min(n - a, max(1, int(release * SR)))
    env[:a] = np.arange(a) / a
    if r > 0:
        env[n - r :] = np.arange(r, 0, -1) / r
    return env


def pluck(freq: float, seconds: float, velocity: float, brightness: float, rng: dsp.Rng) -> np.ndarray:
    """Karplus–Strong: a noise burst circulating in a tuned, damped delay line.

    A one-pole allpass makes up the fractional part of the period, so the
    pitch is exact. `brightness` (0–1) shapes the pluck: low is a thumb on
    gut, high is a nail on wire.
    """
    n = int(seconds * SR)
    # The loop reads one sample ahead and averages two, so it is half a
    # sample shorter than its index offset; the allpass adds the fraction.
    period = SR / freq + 0.5
    length = int(period)
    frac = period - length
    coeff = (1 - frac) / (1 + frac)
    burst = [rng.noise() for _ in range(length)]
    smooth = 1 - brightness
    for i in range(1, length):  # a darker pluck starts from smoother noise
        burst[i] = burst[i] * (1 - smooth) + burst[i - 1] * smooth
    line = burst + [0.0] * (n + 2)
    out = np.empty(n)
    damping = 0.4985 + 0.0013 * brightness
    ap_in = ap_out = 0.0
    for i in range(n):
        sample = line[i]
        out[i] = sample
        averaged = damping * (sample + line[i + 1])
        ap = coeff * averaged + ap_in - coeff * ap_out
        ap_in, ap_out = averaged, ap
        line[i + length] = ap
    return out * velocity


def lute(freq: float, seconds: float, velocity: float, rng: dsp.Rng) -> np.ndarray:
    """A lute course: two gut strings a few cents apart, plucked together."""
    first = pluck(freq, seconds, velocity, 0.35, rng)
    second = pluck(freq * 1.0017, seconds, velocity * 0.8, 0.35, rng)
    tail = decay(len(first), seconds * 0.45)
    return (first + second) * 1.6 * tail


def harp(freq: float, seconds: float, velocity: float, rng: dsp.Rng) -> np.ndarray:
    """A wire-strung harp: bright, long ringing."""
    return pluck(freq, seconds, velocity, 0.75, rng) * 1.1


def recorder(freq: float, seconds: float, velocity: float, rng: dsp.Rng) -> np.ndarray:
    """A recorder: a nearly pure tone with soft upper partials, breath and a
    vibrato that blooms after the attack."""
    n = int(seconds * SR)
    t = np.arange(n) / SR
    bloom = np.minimum(1.0, t / 0.35)
    vibrato = 1 + 0.004 * bloom * sin_turns(t * 5.2)
    phase = _phase(freq, vibrato)
    tone = sin_turns(phase) + 0.18 * sin_turns(2 * phase) + 0.07 * sin_turns(3 * phase) + 0.03 * sin_turns(4 * phase)
    breath = np.array(dsp.bandpass(dsp.white(n, rng), freq * 2, 3.0, SR)) * 0.25
    env = envelope(n, 0.04, min(0.08, seconds / 3))
    return (tone + breath) * env * velocity * 0.22


def _phase(freq: float, vibrato: np.ndarray) -> np.ndarray:
    """A running phase in turns, summed sample by sample so it doesn't
    depend on how a library orders a cumulative sum."""
    out = np.empty(len(vibrato))
    acc = 0.0
    step = freq / SR
    for i, v in enumerate(vibrato.tolist()):
        out[i] = acc
        acc += step * v
        if acc >= 1:
            acc -= 1
    return out


def drone(freq: float, seconds: float, velocity: float, rng: dsp.Rng) -> np.ndarray:
    """A hurdy-gurdy drone: a bowed, reedy tone with a faint buzz, swelling in."""
    n = int(seconds * SR)
    phase = _phase(freq, np.ones(n))
    tone = np.zeros(n)
    for k, amp in ((1, 1.0), (2, 0.55), (3, 0.4), (4, 0.25), (5, 0.18), (6, 0.1), (7, 0.07)):
        tone = tone + amp * sin_turns(k * phase)
    wheel = 0.85 + 0.15 * sin_turns(np.arange(n) / SR * 3.1)
    env = envelope(n, 0.8, 1.2)
    return tone * wheel * env * velocity * 0.05


def frame_drum(seconds: float, velocity: float, rim: bool, rng: dsp.Rng) -> np.ndarray:
    """A frame drum: a low skin thump, or with `rim` a dry tap near the edge."""
    n = int(seconds * SR)
    noise = np.array(dsp.white(n, rng))
    if rim:
        body = np.array(dsp.mode(n, 420, 0.04, SR, 0.6)) + np.array(dsp.bandpass(noise.tolist(), 2500, 1.5, SR)) * 0.8
        tail = decay(n, 0.03)
    else:
        body = np.array(dsp.mode(n, 82, 0.22, SR, 1.0)) + np.array(dsp.mode(n, 131, 0.12, SR, 0.4))
        body = body + np.array(dsp.lowpass(noise.tolist(), 900, SR)) * 0.6 * decay(n, 0.02)
        tail = decay(n, 0.25)
    return body * tail * velocity * 0.6


def comb(signal: np.ndarray, delay: int, gain: float) -> np.ndarray:
    """y[n] = x[n] + g·y[n−D], in blocks of D samples."""
    out = signal.copy()
    for start in range(delay, len(out), delay):
        end = min(start + delay, len(out))
        out[start:end] = out[start:end] + gain * out[start - delay : end - delay]
    return out


def allpass(signal: np.ndarray, delay: int, gain: float) -> np.ndarray:
    """y[n] = −g·x[n] + x[n−D] + g·y[n−D], in blocks of D samples."""
    out = -gain * signal
    for start in range(delay, len(out), delay):
        end = min(start + delay, len(out))
        out[start:end] = out[start:end] + signal[start - delay : end - delay] + gain * out[start - delay : end - delay]
    return out


def hall(signal: np.ndarray, wet: float = 0.22) -> np.ndarray:
    """A small stone hall: four parallel combs into two allpasses, darkened."""
    scale = SR / 44100
    combs = [comb(signal, int(d * scale), g) for d, g in ((1557, 0.82), (1617, 0.81), (1491, 0.8), (1422, 0.79))]
    tail = (combs[0] + combs[1] + combs[2] + combs[3]) * 0.25
    tail = allpass(allpass(tail, int(225 * scale), 0.5), int(556 * scale), 0.5)
    tail = np.array(dsp.lowpass(tail.tolist(), 3800, SR))
    return signal * (1 - wet) + tail * wet
