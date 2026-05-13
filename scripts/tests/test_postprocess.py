"""Pure-function tests for `generate_sprites_ai.postprocess`.

Each function is a pure (image, kwargs) -> image transform. No I/O, no
network.
"""

from __future__ import annotations

from PIL import Image

from generate_sprites_ai.postprocess import (
    chroma_key,
    downsample,
    quantize,
    preserve_outline,
)


def _solid(size: tuple[int, int], color: tuple[int, int, int]) -> Image.Image:
    return Image.new("RGB", size, color)


def test_chroma_key_converts_magenta_to_alpha_zero() -> None:
    img = _solid((4, 4), (255, 0, 255))
    out = chroma_key(img, hex_color="#FF00FF")
    assert out.mode == "RGBA"
    for x in range(4):
        for y in range(4):
            r, g, b, a = out.getpixel((x, y))
            assert a == 0, f"({x},{y}) expected alpha 0, got {a}"


def test_chroma_key_leaves_other_colours_opaque() -> None:
    img = Image.new("RGB", (2, 1), (255, 0, 255))
    img.putpixel((1, 0), (0, 128, 64))
    out = chroma_key(img, hex_color="#FF00FF")
    assert out.getpixel((0, 0))[3] == 0
    r, g, b, a = out.getpixel((1, 0))
    assert (r, g, b, a) == (0, 128, 64, 255)


def test_downsample_nearest_does_not_blur() -> None:
    img = Image.new("RGB", (4, 4), (255, 0, 255))
    img.putpixel((0, 0), (0, 0, 0))
    out = downsample(img, (2, 2), mode="nearest")
    assert out.size == (2, 2)
    # No anti-aliased smear between (0,0) black and the magenta field —
    # the nearest-neighbour resampler picks one source pixel per dest.
    px = out.getpixel((0, 0))
    assert px == (0, 0, 0) or px == (255, 0, 255), \
        f"nearest must keep source pixel intact, got {px}"


def test_downsample_bicubic_returns_target_size() -> None:
    img = Image.new("RGB", (8, 8), (255, 0, 255))
    out = downsample(img, (4, 4), mode="bicubic")
    assert out.size == (4, 4)


def test_quantize_to_two_color_palette() -> None:
    img = Image.new("RGB", (2, 2), (0, 0, 0))
    img.putpixel((1, 1), (200, 200, 200))
    palette = [(0, 0, 0), (255, 255, 255)]
    out = quantize(img, palette)
    # Every output pixel MUST be one of the palette entries.
    for x in range(2):
        for y in range(2):
            assert out.convert("RGB").getpixel((x, y)) in palette


def test_preserve_outline_keeps_dark_silhouette_intact() -> None:
    # 3x3 image: dark outline ring (#1A1410), inner pixel is mid-tone.
    img = Image.new("RGB", (3, 3), (0x1A, 0x14, 0x10))
    img.putpixel((1, 1), (0x80, 0x80, 0x80))
    palette = [(0x1A, 0x14, 0x10), (0x80, 0x80, 0x80)]
    quant = quantize(img, palette)
    out = preserve_outline(quant)
    # Outline pixels (the 8-pixel ring) MUST still be #1A1410.
    for x in [0, 2]:
        for y in [0, 1, 2]:
            assert out.convert("RGB").getpixel((x, y)) == (0x1A, 0x14, 0x10)
    for y in [0, 2]:
        for x in [0, 1, 2]:
            assert out.convert("RGB").getpixel((x, y)) == (0x1A, 0x14, 0x10)
