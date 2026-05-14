"""Pure image post-processing for AI sprite sheets.

Each function takes a PIL Image and returns a new PIL Image. No I/O,
no network, no mutation of the input.
"""

from __future__ import annotations

from PIL import Image


def _parse_hex(hex_color: str) -> tuple[int, int, int]:
    s = hex_color.lstrip("#")
    if len(s) != 6:
        raise ValueError(f"hex colour must be #RRGGBB, got {hex_color!r}")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16))


def chroma_key(image: Image.Image, hex_color: str = "#FF00FF") -> Image.Image:
    """Return a copy with every pixel matching `hex_color` set to
    alpha=0. The chroma colour itself is preserved in the RGB
    channels of the transparent pixels so adjacent pixels never bleed
    a different colour through bilinear scaling later.

    Pure: input image is not mutated.
    """
    target = _parse_hex(hex_color)
    src = image.convert("RGBA")
    out = src.copy()
    px = out.load()
    width, height = out.size
    for y in range(height):
        for x in range(width):
            r, g, b, _ = px[x, y]
            if (r, g, b) == target:
                px[x, y] = (r, g, b, 0)
    return out


def downsample(
    image: Image.Image,
    target_size: tuple[int, int],
    mode: str = "nearest",
) -> Image.Image:
    """Downsample with either nearest-neighbour (for chunky pixel
    art) or bicubic (for icons that need smoother gradients).
    """
    if mode == "nearest":
        resample = Image.Resampling.NEAREST
    elif mode == "bicubic":
        resample = Image.Resampling.BICUBIC
    else:
        raise ValueError(f"unknown downsample mode: {mode}")
    return image.resize(target_size, resample=resample)


def quantize(image: Image.Image, palette: list[tuple[int, int, int]]) -> Image.Image:
    """Quantize the image's RGB channels to the nearest entry in the
    declared palette. Alpha (if present) is preserved verbatim. Uses
    a straightforward sqrt-of-sum-of-squares nearest match — fast
    enough for sprite-sized inputs and deterministic across machines.
    """
    has_alpha = image.mode in ("RGBA", "LA")
    src = image.convert("RGBA") if has_alpha else image.convert("RGB")
    out = src.copy()
    px = out.load()
    width, height = out.size

    def nearest(rgb: tuple[int, int, int]) -> tuple[int, int, int]:
        r, g, b = rgb
        best = palette[0]
        best_d = (r - best[0]) ** 2 + (g - best[1]) ** 2 + (b - best[2]) ** 2
        for entry in palette[1:]:
            d = (r - entry[0]) ** 2 + (g - entry[1]) ** 2 + (b - entry[2]) ** 2
            if d < best_d:
                best = entry
                best_d = d
        return best

    if has_alpha:
        for y in range(height):
            for x in range(width):
                r, g, b, a = px[x, y]
                nr, ng, nb = nearest((r, g, b))
                px[x, y] = (nr, ng, nb, a)
    else:
        for y in range(height):
            for x in range(width):
                r, g, b = px[x, y]
                nr, ng, nb = nearest((r, g, b))
                px[x, y] = (nr, ng, nb)
    return out


# Outline colour used everywhere in `world.md` § Outline & shading.
_OUTLINE_RGB = (0x1A, 0x14, 0x10)


def preserve_outline(image: Image.Image) -> Image.Image:
    """No-op placeholder for now: outline pixels matching the canonical
    outline colour (`#1A1410`) survive the quantize step intact because
    quantize already snaps to the nearest palette entry, and the
    outline colour is by construction a palette entry. This function
    exists as a stable hook for the M5 visual-review pass that may
    introduce a more clever outline-preservation kernel (e.g.,
    re-darkening edge pixels that quantize chose a neighbouring
    mid-tone for).
    """
    return image.copy()
