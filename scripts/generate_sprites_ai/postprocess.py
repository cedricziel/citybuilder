"""Pure image post-processing for AI sprite sheets.

Each function takes a PIL Image and returns a new PIL Image. No I/O,
no network, no mutation of the input.
"""

from __future__ import annotations

from PIL import Image


def threshold_alpha(image: Image.Image, threshold: int = 128) -> Image.Image:
    """Force binary alpha on an RGBA image: pixels with alpha
    `>= threshold` snap to alpha=255 (fully opaque), pixels below
    snap to alpha=0 (fully transparent).

    Runs before downsampling. The image model emits soft-alpha
    silhouette edges when called with `background: "transparent"`;
    a half-pixel alpha gradient looks fine at native resolution but
    smears under nearest-neighbour downsampling at the pixel-art
    scale, producing ragged single-pixel halos. Hard-thresholding
    here keeps every edge crisp.

    Pure: input image is not mutated.
    """
    src = image.convert("RGBA")
    r, g, b, a = src.split()
    binary = a.point(lambda v: 255 if v >= threshold else 0)
    return Image.merge("RGBA", (r, g, b, binary))


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


def in_diamond(x: int, y: int, width: int, height: int) -> bool:
    """True when pixel (x, y)'s centre lies inside the iso diamond
    inscribed in a `width × height` canvas. Mirrors `DiamondMask` in
    the Swift content gate so both sides agree on every pixel."""
    dx = abs((x + 0.5) - width / 2) / (width / 2)
    dy = abs((y + 0.5) - height / 2) / (height / 2)
    return dx + dy <= 1


def diamond_bbox(width: int, height: int) -> tuple[int, int, int, int]:
    """Bounding box (left, top, right, bottom) of the diamond's pixels."""
    xs = [x for y in range(height) for x in range(width) if in_diamond(x, y, width, height)]
    ys = [y for y in range(height) for x in range(width) if in_diamond(x, y, width, height)]
    return min(xs), min(ys), max(xs) + 1, max(ys) + 1


def diamond_fit(image: Image.Image) -> Image.Image:
    """Scale a terrain sprite's opaque region to the diamond's extent, then
    clip it to the iso diamond, so adjacent tiles meet without gaps.

    Nearest-neighbour throughout, so the step is deterministic and
    keeps the palette. An empty sprite comes back empty.
    """
    src = image.convert("RGBA")
    width, height = src.size
    bbox = src.getchannel("A").point(lambda v: 255 if v >= 128 else 0).getbbox()
    if bbox is None:
        return src.copy()
    left, top, right, bottom = diamond_bbox(width, height)
    scaled = src.crop(bbox).resize((right - left, bottom - top), resample=Image.Resampling.NEAREST)
    fitted = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    fitted.paste(scaled, (left, top))
    px = fitted.load()
    for y in range(height):
        for x in range(width):
            if not in_diamond(x, y, width, height):
                px[x, y] = (0, 0, 0, 0)
    return fitted
