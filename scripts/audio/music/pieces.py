"""The scores. Original tunes, in the modes the period's folk music used."""

from __future__ import annotations

from audio.music.score import Piece, Section

# "The Bridge at Dawn": the title theme. D Dorian, a gentle 3/4, built to
# loop: it ends on the tonic it starts from.
_DAWN_A = "d5:1 e5:1 f5:1  e5:1.5 d5:.5 c5:1  d5:1 a4:2  c5:1 b4:1 a4:1  d5:1 f5:1 a5:1  g5:1.5 f5:.5 e5:1  f5:1 e5:1 c5:1  d5:3"
_DAWN_B = "a5:1 g5:1 f5:1  e5:1 g5:2  f5:1 e5:1 d5:1  e5:3  a5:1 c6:1 a5:1  b5:1.5 a5:.5 g5:1  a5:1 e5:1 c5:1  e5:2 r:1"

BRIDGE_AT_DAWN = Piece(
    path="music/bridge-at-dawn.caf",
    title="The Bridge at Dawn",
    bpm=88,
    beats_per_bar=3,
    tonic="d3",
    seed=301,
    sections=[
        Section("Dm C Dm Am Dm G Am Dm", _DAWN_A, "recorder", ("harp", "drone")),
        Section("F C Dm Am F G Am Am", _DAWN_B, "recorder", ("harp", "lute", "drone")),
        Section("Dm C Dm Am Dm G Am Dm", _DAWN_A, "lute", ("harp", "drone", "drum"), octave=-1),
        Section("Dm C Dm Am Dm G Am Dm", _DAWN_A, "recorder", ("harp", "lute", "drone", "drum")),
    ],
)

# "Hearth and Harvest": the calm building theme. G Mixolydian (the flat
# seventh, F, over a G drone), an unhurried 4/4.
_HEARTH_A = ("g4:1 b4:1 d5:1.5 c5:.5  c5:1 a4:1 f4:2  g4:1 a4:1 b4:1 d5:1  d5:2 a4:2  "
             "b4:1 d5:1 g5:1.5 f5:.5  e5:1 g5:1 c5:2  f5:1 e5:.5 d5:.5 c5:1 a4:1  g4:4")
_HEARTH_B = ("e5:2 g5:2  d5:1.5 b4:.5 g4:2  a4:1 c5:1 f5:1 e5:1  d5:4  "
             "e5:1 g5:1 b5:1.5 a5:.5  g5:1 e5:1 c5:2  d5:1 f#5:1 a5:1 f#5:1  g5:4")
_HEARTH_A_CHORDS = "G F G D G C F G"
_HEARTH_B_CHORDS = "C G F G Em C D G"

HEARTH_AND_HARVEST = Piece(
    path="music/hearth-and-harvest.caf",
    title="Hearth and Harvest",
    bpm=76,
    beats_per_bar=4,
    tonic="g2",
    seed=311,
    sections=[
        Section("G F G G", "", "harp", ("harp", "drone")),
        Section(_HEARTH_A_CHORDS, _HEARTH_A, "recorder", ("harp", "drone")),
        Section(_HEARTH_A_CHORDS, _HEARTH_A, "lute", ("harp", "drone"), octave=-1),
        Section(_HEARTH_B_CHORDS, _HEARTH_B, "recorder", ("lute", "drone")),
        Section(_HEARTH_A_CHORDS, _HEARTH_A, "recorder", ("harp", "lute", "drone", "drum")),
        Section(_HEARTH_B_CHORDS, _HEARTH_B, "lute", ("harp", "drone", "drum"), octave=-1),
        Section("C F G G", "", "harp", ("harp", "drone")),
    ],
)

# "Market Day": the lively summer theme. D Mixolydian, a quick dance in 3.
_MARKET_A = ("d5:.5 e5:.5 f#5:1 d5:1  e5:.5 d5:.5 c5:1 e5:1  f#5:.5 g5:.5 a5:1 f#5:1  g5:1 b5:.5 a5:.5 g5:1  "
             "f#5:.5 e5:.5 d5:1 a4:1  c5:.5 d5:.5 e5:1 g5:1  b4:.5 c5:.5 d5:1 b4:1  d5:3")
_MARKET_B = ("b5:1 a5:.5 g5:.5 f#5:1  a5:1 f#5:.5 e5:.5 d5:1  e5:.5 f#5:.5 g5:1 e5:1  f#5:3  "
             "g5:.5 a5:.5 b5:1 g5:1  a5:.5 g5:.5 e5:1 c5:1  e5:1 d5:.5 c5:.5 b4:1  d5:3")
_MARKET_A_CHORDS = "D C D G D C G D"
_MARKET_B_CHORDS = "G D C D G Am C D"

MARKET_DAY = Piece(
    path="music/market-day.caf",
    title="Market Day",
    bpm=126,
    beats_per_bar=3,
    tonic="d3",
    seed=313,
    sections=[
        Section(_MARKET_A_CHORDS, _MARKET_A, "recorder", ("lute", "drone", "drum")),
        Section(_MARKET_A_CHORDS, _MARKET_A, "lute", ("harp", "drum"), octave=-1),
        Section(_MARKET_B_CHORDS, _MARKET_B, "recorder", ("lute", "drone", "drum")),
        Section(_MARKET_B_CHORDS, _MARKET_B, "harp", ("lute", "drum")),
        Section(_MARKET_A_CHORDS, _MARKET_A, "recorder", ("harp", "lute", "drone", "drum")),
        Section("D C G D", "", "harp", ("lute", "drum")),
        Section(_MARKET_A_CHORDS, _MARKET_A, "lute", ("harp", "drone", "drum")),
        Section(_MARKET_B_CHORDS, _MARKET_B, "recorder", ("harp", "drone", "drum")),
        Section(_MARKET_A_CHORDS, _MARKET_A, "harp", ("lute", "drone", "drum")),
        Section(_MARKET_B_CHORDS, _MARKET_B, "lute", ("harp", "drum"), octave=-1),
        Section(_MARKET_A_CHORDS, _MARKET_A, "recorder", ("harp", "lute", "drone", "drum")),
    ],
)

# "The Long Night": the sparse winter theme. A Aeolian, slow, no drum.
_NIGHT_A = "a4:2 c5:2  b4:2 g4:2  a4:3 e4:1  g4:4  f4:2 a4:2  g4:1 b4:1 d5:2  c5:2 b4:2  a4:4"
_NIGHT_B = "c5:2 a4:2  g4:2 e4:2  f4:2 a4:2  b4:2 g4:2  a4:2 c5:2  b4:4"
_NIGHT_A_CHORDS = "Am G Am Em F G Am Am"

LONG_NIGHT = Piece(
    path="music/long-night.caf",
    title="The Long Night",
    bpm=58,
    beats_per_bar=4,
    tonic="a2",
    seed=317,
    sections=[
        Section("Am Am Em Am", "", "harp", ("drone",)),
        Section(_NIGHT_A_CHORDS, _NIGHT_A, "recorder", ("harp", "drone"), octave=-1),
        Section(_NIGHT_A_CHORDS, _NIGHT_A, "harp", ("drone",)),
        Section("F C Dm Em F Em", _NIGHT_B, "recorder", ("harp", "drone")),
        Section(_NIGHT_A_CHORDS, _NIGHT_A, "lute", ("harp", "drone"), octave=-1),
    ],
)

# "Ships on the Sound": for spring and autumn. E Dorian, a steady 4/4.
_SHIPS_A = ("e5:1 g5:1 f#5:1 e5:1  d5:1.5 e5:.5 f#5:2  e5:1 b4:1 e5:1 g5:1  f#5:2 d5:2  "
            "e5:1 f#5:1 g5:1 a5:1  b5:1.5 a5:.5 g5:1 f#5:1  e5:1 d5:1 b4:1 d5:1  e5:4")
_SHIPS_B = ("d5:1 g5:1 b5:2  a5:1 f#5:1 d5:2  e5:1 g5:1 b5:1 g5:1  a5:2 c#6:2  "
            "b5:1 a5:1 g5:1 f#5:1  f#5:1 e5:1 d5:2  d5:1 f#5:1 b5:2  e5:4")
_SHIPS_A_CHORDS = "Em D Em Bm Em A G Em"
_SHIPS_B_CHORDS = "G D Em A G D Bm Em"

SHIPS_ON_THE_SOUND = Piece(
    path="music/ships-on-the-sound.caf",
    title="Ships on the Sound",
    bpm=100,
    beats_per_bar=4,
    tonic="e2",
    seed=331,
    sections=[
        Section(_SHIPS_A_CHORDS, _SHIPS_A, "recorder", ("harp", "drone")),
        Section(_SHIPS_A_CHORDS, _SHIPS_A, "lute", ("harp", "drone"), octave=-1),
        Section(_SHIPS_B_CHORDS, _SHIPS_B, "recorder", ("lute", "drone", "drum")),
        Section(_SHIPS_A_CHORDS, _SHIPS_A, "recorder", ("harp", "lute", "drone", "drum")),
        Section(_SHIPS_B_CHORDS, _SHIPS_B, "lute", ("harp", "drone", "drum"), octave=-1),
        Section(_SHIPS_A_CHORDS, _SHIPS_A, "recorder", ("harp", "lute", "drone", "drum")),
        Section(_SHIPS_A_CHORDS, _SHIPS_A, "harp", ("drone",)),
    ],
)

PIECES = [BRIDGE_AT_DAWN, HEARTH_AND_HARVEST, MARKET_DAY, LONG_NIGHT, SHIPS_ON_THE_SOUND]
