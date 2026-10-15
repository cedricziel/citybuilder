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


def metal_strike(sr: int, pitch: float, rng: dsp.Rng, length: float = 0.9) -> list[float]:
    """Hammer on an anvil: a bright click, then inharmonic ringing modes."""
    n = int(length * sr)
    out = dsp.mul(dsp.highpass(dsp.white(n, rng), 3000, sr), dsp.decay_env(n, 0.0003, 0.003, sr))
    for ratio, decay, amp in ((1.0, 0.35, 0.6), (2.76, 0.22, 0.5), (5.40, 0.12, 0.35), (8.93, 0.07, 0.2)):
        dsp.mix_into(out, dsp.mode(n, pitch * ratio, decay, sr, amp), 0)
    return out


def swell(n: int, rng: dsp.Rng, cutoff: float, sr: int, rate: float) -> list[float]:
    """Filtered noise breathing in and out `rate` times over its length."""
    noise = dsp.lowpass(dsp.lowpass(dsp.white(n, rng), cutoff, sr), cutoff, sr)
    return [x * (0.55 + 0.45 * dsp.sin_turns(i * rate / n)) for i, x in enumerate(noise)]


def fields() -> list[float]:
    """Wind through standing crops, a sickle swishing twice, a hoe tapping the soil."""
    rng = dsp.Rng(61)
    n = int(4.0 * SR)
    wind = dsp.bandpass(swell(n + SR // 2, rng, 1800, SR, 1), 700, 0.7, SR)
    out = dsp.loop_crossfade(wind, n)
    for at in (0.8, 2.6):
        m = int(0.32 * SR)
        swish = dsp.bandpass(dsp.white(m, rng), 4200, 1.5, SR)
        shape = [dsp.sin_turns(i / m / 2) * dsp.sin_turns(i / m / 2) * dsp.sin_turns(i / m / 2) for i in range(m)]
        dsp.mix_into(out, dsp.mul(swish, shape), int(at * SR), 0.9, wrap=True)
    dsp.mix_into(out, wood_knock(SR, 140, rng, 0.2), int(1.7 * SR), 0.5, wrap=True)
    return out


def mill() -> list[float]:
    """Millstones rumbling under a turning shaft that creaks once a revolution."""
    rng = dsp.Rng(67)
    n = int(4.0 * SR)
    rumble = dsp.loop_crossfade(dsp.lowpass(swell(n + SR // 2, rng, 160, SR, 2), 220, SR), n)
    out = dsp.scale(rumble, 3.0)
    for at in (0.3, 2.3):
        m = int(0.45 * SR)
        phase = 0.0
        creak = []
        for i in range(m):
            t = i / m
            phase += (190 + 70 * t) / SR
            saw = phase - int(phase) - 0.5
            env = dsp.sin_turns(t / 2)
            creak.append(saw * env * env * (0.7 + 0.3 * rng.noise()))
        dsp.mix_into(out, dsp.bandpass(creak, 900, 2.5, SR), int(at * SR), 0.9, wrap=True)
    return room(out, SR, wrap=True)


def oven() -> list[float]:
    """A wood fire: a low roar with sparks crackling at random."""
    rng = dsp.Rng(71)
    n = int(4.0 * SR)
    roar = dsp.loop_crossfade(dsp.bandpass(swell(n + SR // 2, rng, 900, SR, 3), 250, 0.6, SR), n)
    out = dsp.scale(roar, 2.0)
    t = 0.0
    while t < 4.0:
        m = int(rng.uniform(0.002, 0.008) * SR)
        crack = dsp.mul(dsp.highpass(dsp.white(m, rng), 2000, SR), dsp.decay_env(m, 0.0002, m / SR / 3, SR))
        dsp.mix_into(out, crack, int(t * SR), rng.uniform(0.2, 0.9), wrap=True)
        t += rng.uniform(0.03, 0.35)
    return out


def forge() -> list[float]:
    """A smith at the anvil: two heavy blows and a light one, with the bellows breathing."""
    rng = dsp.Rng(73)
    n = int(3.0 * SR)
    bellows = dsp.loop_crossfade(dsp.bandpass(swell(n + SR // 2, rng, 1200, SR, 1), 320, 0.8, SR), n)
    out = dsp.scale(bellows, 0.8)
    for at, pitch, gain in ((0.2, 860.0, 1.0), (0.75, 870.0, 0.95), (1.15, 1240.0, 0.4)):
        dsp.mix_into(out, metal_strike(SR, pitch, rng), int(at * SR), gain, wrap=True)
    return room(out, SR, wrap=True)


def mine() -> list[float]:
    """A pick biting rock, chips of stone skittering after each blow."""
    rng = dsp.Rng(79)
    n = int(3.0 * SR)
    out = dsp.silence(n)
    for at in (0.15, 1.6):
        m = int(0.3 * SR)
        hit = dsp.mul(dsp.highpass(dsp.white(m, rng), 1200, SR), dsp.decay_env(m, 0.0002, 0.012, SR))
        for ratio, decay in ((1.0, 0.03), (1.9, 0.02), (3.3, 0.015)):
            dsp.mix_into(hit, dsp.mode(m, 1450 * ratio, decay, SR, 0.4), 0)
        dsp.mix_into(out, hit, int(at * SR), 1.0, wrap=True)
        for k in range(6):
            chip = dsp.mul(dsp.bandpass(dsp.white(400, rng), rng.uniform(2500, 5000), 3, SR), dsp.decay_env(400, 0.0002, 0.002, SR))
            dsp.mix_into(out, chip, int((at + 0.08 + k * rng.uniform(0.02, 0.06)) * SR), rng.uniform(0.15, 0.4), wrap=True)
    return room(out, SR, wrap=True, wet=0.55)


def bubble(sr: int, freq: float, length: float) -> list[float]:
    """One bubble bursting: a quick decaying tone whose pitch rises as it shrinks."""
    n = int(length * sr)
    phase = 0.0
    out = []
    for i in range(n):
        t = i / n
        phase += freq * (1 + 1.5 * t) / sr
        out.append((1 - t) * (1 - t) * dsp.sin_turns(phase))
    return out


def brewing() -> list[float]:
    """A vat working: bubbles rising through wort, a low slosh underneath."""
    rng = dsp.Rng(83)
    n = int(4.0 * SR)
    out = dsp.scale(dsp.loop_crossfade(dsp.lowpass(swell(n + SR // 2, rng, 300, SR, 2), 400, SR), n), 1.5)
    t = 0.0
    while t < 4.0:
        dsp.mix_into(out, bubble(SR, rng.uniform(300, 950), rng.uniform(0.02, 0.06)), int(t * SR), rng.uniform(0.15, 0.5), wrap=True)
        t += rng.uniform(0.04, 0.25)
    return room(out, SR, wrap=True)


def shipwright() -> list[float]:
    """Caulking a hull: a mallet driving a caulking iron, in a broken rhythm."""
    rng = dsp.Rng(89)
    n = int(3.0 * SR)
    out = dsp.silence(n)
    for at in (0.0, 0.32, 0.64, 1.4, 1.72, 2.25):
        dsp.mix_into(out, wood_knock(SR, rng.uniform(125, 140), rng, 0.35), int(at * SR), 1.0, wrap=True)
        dsp.mix_into(out, dsp.mode(int(0.15 * SR), 2300, 0.03, SR, 0.15), int(at * SR), 1.0, wrap=True)
    return room(out, SR, wrap=True, wet=0.5)


# Partials of a cast bronze bell (hum, prime, tierce, quint, nominal and up),
# each with its share of the strike and how long it rings relative to the hum.
BELL_PARTIALS = ((0.5, 0.5, 1.0), (1.0, 1.0, 0.7), (1.183, 0.6, 0.55), (1.506, 0.35, 0.45),
                 (2.0, 0.55, 0.35), (2.514, 0.25, 0.25), (3.011, 0.2, 0.18), (4.166, 0.12, 0.12))


def bell(sr: int, pitch: float, ring: float, rng: dsp.Rng, length: float | None = None) -> list[float]:
    """A struck bell at `pitch` (its prime), the hum ringing for about `ring` seconds."""
    n = int((length or ring * 1.6) * sr)
    out = dsp.mul(dsp.bandpass(dsp.white(n, rng), pitch * 3, 1.0, sr), dsp.decay_env(n, 0.0005, 0.008, sr))
    out = dsp.scale(out, 0.4)
    for ratio, amp, life in BELL_PARTIALS:
        # A slight detuning beats against the partial, as in a real casting.
        for detune in (1.0, 1.0015):
            dsp.mix_into(out, dsp.mode(n, pitch * ratio * detune, ring * life, sr, amp * 0.5, rng.uniform(0, 1)), 0)
    return dsp.fade_edges(out, 0.0005, 0.05, sr)


def peal(pitches: list[float], gap: float, ring: float, seed: int) -> list[float]:
    rng = dsp.Rng(seed)
    n = int((gap * len(pitches) + ring * 1.6) * SR)
    out = dsp.silence(n)
    for k, pitch in enumerate(pitches):
        dsp.mix_into(out, bell(SR, pitch, ring, rng), int(k * gap * SR), 0.9 if k else 1.0)
    return dsp.fade_edges(room(out, SR, wet=0.4), 0.0005, 0.2, SR)


def coins(seed: int, count: int) -> list[float]:
    """A handful of coins settling: bright, short metal clinks tumbling closer together."""
    rng = dsp.Rng(seed)
    n = int(0.6 * SR)
    out = dsp.silence(n)
    t = 0.0
    for k in range(count):
        m = int(0.12 * SR)
        clink = dsp.mul(dsp.highpass(dsp.white(m, rng), 5000, SR), dsp.decay_env(m, 0.0002, 0.002, SR))
        base = rng.uniform(3800, 5200)
        for ratio, decay in ((1.0, 0.05), (2.41, 0.03), (3.9, 0.02)):
            dsp.mix_into(clink, dsp.mode(m, base * ratio, decay, SR, 0.4), 0)
        dsp.mix_into(out, clink, int(t * SR), 1.0 - 0.6 * k / count)
        t += rng.uniform(0.03, 0.09) * (1 - 0.5 * k / count)
    return dsp.fade_edges(room(out, SR, wet=0.2), 0.0005, 0.05, SR)


def demolish() -> list[float]:
    """Timber giving way: a creak, a crack, then beams tumbling onto each other."""
    rng = dsp.Rng(101)
    n = int(1.6 * SR)
    out = dsp.silence(n)
    crack = dsp.mul(dsp.lowpass(dsp.white(int(0.4 * SR), rng), 2500, SR), dsp.decay_env(int(0.4 * SR), 0.002, 0.08, SR))
    dsp.mix_into(out, crack, int(0.05 * SR), 1.2)
    t = 0.15
    for _ in range(7):
        dsp.mix_into(out, wood_knock(SR, rng.uniform(90, 180), rng, 0.4), int(t * SR), rng.uniform(0.5, 1.0))
        t += rng.uniform(0.06, 0.18)
    rumble = dsp.mul(dsp.lowpass(dsp.white(n, rng), 200, SR), dsp.decay_env(n, 0.1, 0.4, SR))
    dsp.mix_into(out, rumble, 0, 2.0)
    return dsp.fade_edges(room(out, SR, wet=0.5), 0.0005, 0.2, SR)


def rejected() -> list[float]:
    """Two dull knocks, lower the second time: no."""
    rng = dsp.Rng(103)
    out = dsp.silence(int(0.45 * SR))
    dsp.mix_into(out, wood_knock(SR, 150, rng, 0.25), 0, 1.0)
    dsp.mix_into(out, wood_knock(SR, 118, rng, 0.25), int(0.14 * SR), 0.9)
    return dsp.fade_edges(out, 0.0005, 0.03, SR)


def chimes(pitches: list[float], gap: float, seed: int, ring: float = 1.2) -> list[float]:
    """Small bells struck lightly, like a wind chime or a hand chime."""
    rng = dsp.Rng(seed)
    n = int((gap * len(pitches) + ring * 1.6) * SR)
    out = dsp.silence(n)
    for k, pitch in enumerate(pitches):
        dsp.mix_into(out, bell(SR, pitch, ring, rng), int((k * gap + rng.uniform(0, gap * 0.2)) * SR), rng.uniform(0.6, 1.0))
    return dsp.fade_edges(room(out, SR, wet=0.3), 0.0005, 0.2, SR)


def embers() -> list[float]:
    """A fire going out: a falling hiss and the last few crackles."""
    rng = dsp.Rng(107)
    n = int(1.2 * SR)
    hiss = dsp.highpass(dsp.white(n, rng), 2500, SR)
    out = [x * (1 - i / n) * (1 - i / n) * 0.6 for i, x in enumerate(hiss)]
    for _ in range(6):
        m = int(0.005 * SR)
        crack = dsp.mul(dsp.highpass(dsp.white(m, rng), 2000, SR), dsp.decay_env(m, 0.0002, 0.0015, SR))
        dsp.mix_into(out, crack, int(rng.uniform(0.0, 0.8) * SR), rng.uniform(0.4, 1.0))
    return dsp.fade_edges(out, 0.005, 0.1, SR)


# D Dorian, the mode the period tunes lean on: the pitches the bells and chimes use.
D4, E4, F4, G4, A4, B4, C5, D5, E5, A5 = 293.66, 329.63, 349.23, 392.0, 440.0, 493.88, 523.25, 587.33, 659.26, 880.0


SOUNDS = [
    Sound("loop/sawmill.caf", "Sawmill: frame saw", "loop", sawmill),
    Sound("loop/lumberjack.caf", "Lumberjack: axe on timber", "loop", lumberjack),
    Sound("sfx/carrier-clink.caf", "Carrier sets goods down", "sfx", carrier_clink),
    Sound("ambient/forest-birds.caf", "Spring wood with birdsong", "ambient", forest_birds),
    Sound("loop/fields.caf", "Fields: wind in the crops and a sickle", "loop", fields),
    Sound("loop/mill.caf", "Mill: millstones and a creaking shaft", "loop", mill),
    Sound("loop/oven.caf", "Oven: a crackling wood fire", "loop", oven),
    Sound("loop/forge.caf", "Forge: anvil and bellows", "loop", forge),
    Sound("loop/mine.caf", "Mine: a pick on rock", "loop", mine),
    Sound("loop/brewing.caf", "Brewing: a bubbling vat", "loop", brewing),
    Sound("loop/shipwright.caf", "Shipwright: caulking mallet", "loop", shipwright),
    Sound("sfx/demolish.caf", "Timber collapsing", "sfx", demolish),
    Sound("sfx/rejected.caf", "Two dull knocks", "sfx", rejected),
    Sound("sfx/warning-bell.caf", "A low warning bell", "sfx", lambda: peal([D4 / 2], 0.0, 2.2, 109)),
    Sound("sfx/relief.caf", "Two rising chimes", "sfx", lambda: chimes([A4 * 2, D5 * 2], 0.18, 113)),
    Sound("sfx/season.caf", "A wind chime stirs", "sfx", lambda: chimes([D5 * 2, A4 * 2, E5 * 2, C5 * 2, A5 * 2], 0.14, 127, 1.0)),
    Sound("sfx/handbell.caf", "A handbell rung three times", "sfx", lambda: chimes([A5, A5, A5], 0.32, 131, 0.8)),
    Sound("sfx/age-peal.caf", "A peal of four bells", "sfx", lambda: peal([D5, C5, A4, G4], 0.42, 2.0, 137)),
    Sound("sfx/victory-peal.caf", "A rising peal", "sfx", lambda: peal([D4, F4, A4, D5, F4 * 2, A5], 0.3, 1.8, 139)),
    Sound("sfx/great-bell.caf", "A deep great bell", "sfx", lambda: peal([D4 / 2], 0.0, 3.0, 149)),
    Sound("sfx/embers.caf", "Embers hissing out", "sfx", embers),
    Sound("sfx/commission.caf", "A soft two-note chime", "sfx", lambda: chimes([G4 * 2, D5 * 2], 0.22, 151)),
    Sound("sfx/coins-1.caf", "A few coins", "sfx", lambda: coins(157, 4)),
    Sound("sfx/coins-2.caf", "A handful of coins", "sfx", lambda: coins(163, 7)),
    Sound("sfx/coins-3.caf", "A purse emptied", "sfx", lambda: coins(167, 11)),
]


def render(sound: Sound) -> list[float]:
    signal = sound.render()
    if sound.bus == "sfx":
        measured = dsp.loudest_window_rms(signal, SR // 20)
    else:
        measured = dsp.rms(signal)
    return dsp.normalise(signal, LEVELS[sound.bus], measured)
