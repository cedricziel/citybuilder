"""The six files that replaced downloaded audio: right length, level and edges,
and no third-party credit left in the manifest. Nobody has to listen to know
a file is clipped, off-centre, silent or cut off mid-ring."""

from __future__ import annotations

import json
import math
import struct

import pytest

from audio import generate
from tests.test_audio_generator import decode_ima4

# path: (min seconds, max seconds). The five one-shots sit on the sfx bus,
# so their loudest 50 ms lands near its 0.22 RMS target (-13.2 dBFS).
ONE_SHOTS = {
    "ui/click.caf": (0.05, 0.3),
    "ui/place-thunk.caf": (0.3, 0.8),
    "construction/chime.caf": (0.25, 1.0),
    "economy/coin.caf": (0.8, 2.0),
    "economy/game-over.caf": (1.5, 3.5),
}
MUSIC = "music/lanterns-on-the-quay.caf"


def load(path: str) -> tuple[list[float], int]:
    data = (generate.AUDIO_DIR / path).read_bytes()
    assert data[:4] == b"caff"
    pos, rate, frames, payload = 8, 0, 0, b""
    while pos < len(data):
        kind = data[pos : pos + 4]
        size = struct.unpack(">q", data[pos + 4 : pos + 12])[0]
        body = data[pos + 12 : pos + 12 + size]
        if kind == b"desc":
            rate = int(struct.unpack(">d", body[:8])[0])
        elif kind == b"pakt":
            frames = struct.unpack(">q", body[8:16])[0]
        elif kind == b"data":
            payload = body[4:]
        pos += 12 + size
    return [s / 32768 for s in decode_ima4(payload, frames)], rate


def db(x: float) -> float:
    return 20 * math.log10(x) if x > 0 else -math.inf


def loudest_rms(signal: list[float], window: int) -> float:
    best = 0.0
    for i in range(0, max(1, len(signal) - window), window // 4):
        chunk = signal[i : i + window]
        best = max(best, math.sqrt(sum(x * x for x in chunk) / len(chunk)))
    return best


@pytest.mark.parametrize("path", ONE_SHOTS)
def test_one_shot_has_the_right_length_level_and_edges(path):
    signal, rate = load(path)
    low, high = ONE_SHOTS[path]
    assert low <= len(signal) / rate <= high
    assert max(abs(x) for x in signal) <= 0.96  # never clips
    assert abs(sum(signal) / len(signal)) < 0.01  # no DC offset
    assert -15.0 <= db(loudest_rms(signal, rate // 20)) <= -11.5
    assert max(abs(x) for x in signal[-rate // 1000 :]) < 0.01  # ends on silence, not a cut
    assert abs(signal[0]) < 0.02  # no click on the first sample


def test_new_music_piece_has_the_right_length_level_and_edges():
    signal, rate = load(MUSIC)
    assert 120 <= len(signal) / rate <= 160
    assert max(abs(x) for x in signal) <= 0.99
    assert abs(sum(signal) / len(signal)) < 0.01
    overall = math.sqrt(sum(x * x for x in signal) / len(signal))
    assert abs(db(overall) - db(0.12)) < 1.0  # the music bus level the other pieces use
    assert max(abs(x) for x in signal[-rate // 200 :]) < 0.002
    assert abs(signal[0]) < 0.01
    tail = math.sqrt(sum(x * x for x in signal[-rate:]) / rate)
    assert tail < overall / 4  # the last second has faded out


def test_manifest_credits_no_third_party_audio():
    manifest = json.loads(generate.MANIFEST.read_text(encoding="utf-8"))
    assert {e["author"] for e in manifest["entries"]} == {"Citybuilder sound generator", "Citybuilder original score"}
    paths = {e["path"] for e in manifest["entries"]}
    assert "music/bards-tale.m4a" not in paths
    assert not list(generate.AUDIO_DIR.rglob("*.m4a"))
    for path in [*ONE_SHOTS, MUSIC]:
        assert path in paths
