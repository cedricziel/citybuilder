"""Mono IMA4 ADPCM Core Audio Format writer.

IMA4 is what the game's existing sounds use: 4:1 compression that
AVAudioFile decodes on every Apple platform. Encoding it ourselves,
instead of calling afconvert, keeps the bytes identical on every
machine. Apple's variant packs 64 samples into a 34-byte packet: a
big-endian header holding the predictor's top 9 bits and the step
index, then 32 bytes of 4-bit codes, low nibble first.
"""

from __future__ import annotations

import struct

FRAMES_PER_PACKET = 64
BYTES_PER_PACKET = 34

STEPS = [
    7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 19, 21, 23, 25, 28, 31, 34, 37, 41, 45,
    50, 55, 60, 66, 73, 80, 88, 97, 107, 118, 130, 143, 157, 173, 190, 209, 230,
    253, 279, 307, 337, 371, 408, 449, 494, 544, 598, 658, 724, 796, 876, 963,
    1060, 1166, 1282, 1411, 1552, 1707, 1878, 2066, 2272, 2499, 2749, 3024, 3327,
    3660, 4026, 4428, 4871, 5358, 5894, 6484, 7132, 7845, 8630, 9493, 10442, 11487,
    12635, 13899, 15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794, 32767,
]
INDEX_SHIFT = [-1, -1, -1, -1, 2, 4, 6, 8]


def to_pcm16(signal: list[float]) -> list[int]:
    out = []
    for x in signal:
        v = int(round(max(-1.0, min(1.0, x)) * 32767))
        out.append(v)
    return out


def _encode_sample(sample: int, predictor: int, index: int) -> tuple[int, int, int]:
    step = STEPS[index]
    diff = sample - predictor
    code = 0
    if diff < 0:
        code = 8
        diff = -diff
    delta = step >> 3
    if diff >= step:
        code |= 4
        diff -= step
        delta += step
    step >>= 1
    if diff >= step:
        code |= 2
        diff -= step
        delta += step
    step >>= 1
    if diff >= step:
        code |= 1
        delta += step
    predictor = predictor - delta if code & 8 else predictor + delta
    predictor = max(-32768, min(32767, predictor))
    index = max(0, min(88, index + INDEX_SHIFT[code & 7]))
    return code, predictor, index


def _start_state(samples: list[int]) -> tuple[int, int]:
    """Where the first packet starts: on the first sample's top 9 bits, with
    the step size the signal settles to. Starting from silence instead makes
    the decoder jump at the first sample, which clicks at every loop wrap."""
    if not samples:
        return 0, 0
    predictor, index = 0, 0
    for sample in samples[-1024:]:
        _, predictor, index = _encode_sample(sample, predictor, index)
    first = samples[0] & 0xFF80
    return (first - 0x10000 if first >= 0x8000 else first), index


def encode_ima4(samples: list[int]) -> bytes:
    """Encodes PCM16 samples, padding the last packet with silence."""
    padded = samples + [0] * (-len(samples) % FRAMES_PER_PACKET)
    out = bytearray()
    predictor, index = _start_state(samples)
    for start in range(0, len(padded), FRAMES_PER_PACKET):
        # Apple's decoder keeps its running predictor while it agrees with the
        # header's top 9 bits, so the encoder carries its predictor on too.
        header = (predictor & 0xFF80) | index
        out += struct.pack(">H", header & 0xFFFF)
        codes = []
        for sample in padded[start : start + FRAMES_PER_PACKET]:
            code, predictor, index = _encode_sample(sample, predictor, index)
            codes.append(code)
        out += bytes(codes[i] | (codes[i + 1] << 4) for i in range(0, FRAMES_PER_PACKET, 2))
    return bytes(out)


def _chunk(kind: bytes, body: bytes) -> bytes:
    return kind + struct.pack(">q", len(body)) + body


def write_caf(signal: list[float], sample_rate: int) -> bytes:
    """The bytes of a mono IMA4 CAF file holding `signal`."""
    frames = len(signal)
    payload = encode_ima4(to_pcm16(signal))
    packets = len(payload) // BYTES_PER_PACKET
    desc = struct.pack(">dIIIIII", float(sample_rate), int.from_bytes(b"ima4", "big"), 0,
                       BYTES_PER_PACKET, FRAMES_PER_PACKET, 1, 0)
    # kAudioChannelLayoutTag_Mono, no bitmap, no descriptions.
    chan = struct.pack(">III", (100 << 16) | 1, 0, 0)
    remainder = packets * FRAMES_PER_PACKET - frames
    # Constant-size packets carry no table, so the packet count is 0 as afconvert writes it.
    pakt = struct.pack(">qqii", 0, frames, 0, remainder)
    return (b"caff" + struct.pack(">HH", 1, 0)
            + _chunk(b"desc", desc) + _chunk(b"chan", chan) + _chunk(b"pakt", pakt)
            + _chunk(b"data", struct.pack(">I", 0) + payload))
