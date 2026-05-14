"""Pure-function tests for `generate_sprites_ai.postprocess`.

Each function is a pure (image, kwargs) -> image transform. No I/O, no
network.
"""

from __future__ import annotations

from PIL import Image

from generate_sprites_ai.postprocess import (
    downsample,
    preserve_outline,
    quantize,
    threshold_alpha,
)


def _solid(size: tuple[int, int], color: tuple[int, int, int]) -> Image.Image:
    return Image.new("RGB", size, color)


def test_threshold_alpha_snaps_soft_alpha_to_binary() -> None:
    """Pixels with alpha below the threshold become 0, at-or-above
    become 255 — no in-between values survive."""
    img = Image.new("RGBA", (4, 1), (200, 100, 50, 255))
    img.putpixel((0, 0), (200, 100, 50, 0))     # fully transparent
    img.putpixel((1, 0), (200, 100, 50, 64))    # below threshold
    img.putpixel((2, 0), (200, 100, 50, 200))   # above threshold
    img.putpixel((3, 0), (200, 100, 50, 255))   # fully opaque
    out = threshold_alpha(img, threshold=128)
    alphas = [out.getpixel((x, 0))[3] for x in range(4)]
    assert alphas == [0, 0, 255, 255]


def test_threshold_alpha_preserves_rgb_channels() -> None:
    """RGB values pass through unchanged; only the alpha plane is
    rewritten."""
    img = Image.new("RGBA", (1, 1), (200, 100, 50, 200))
    out = threshold_alpha(img, threshold=128)
    r, g, b, a = out.getpixel((0, 0))
    assert (r, g, b) == (200, 100, 50)
    assert a == 255


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
