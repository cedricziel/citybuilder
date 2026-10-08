"""Locally drawn sprites for catalog entries marked
`source = "procedural"`.

Each renderer paints the canonical-size sprite directly in the
`world.md` palette. `render_sheet` upscales it with nearest-neighbour
to the 1024×1024 sheet the rest of the pipeline consumes, so the
offline regen path (sheet → downsample → quantize → indexed PNG)
reproduces the canonical pixels exactly. No network, no randomness
beyond a fixed integer hash: output is byte-identical across runs and
machines.
"""

from __future__ import annotations

from collections.abc import Callable

from PIL import Image

from .postprocess import in_diamond

SHEET_SIZE = 1024
TILE = (64, 32)

Rgb = tuple[int, int, int]

# `world.md` palette roles used here.
DARK_LOAM: Rgb = (0x3D, 0x2A, 0x1D)
MEDIUM_LOAM: Rgb = (0x5C, 0x3F, 0x28)
LIGHT_LOAM: Rgb = (0x8C, 0x6A, 0x45)
SAND: Rgb = (0xC9, 0xA6, 0x71)
LEAF: Rgb = (0x5C, 0x80, 0x38)
SHADOW_GREEN: Rgb = (0x3F, 0x5C, 0x26)
SUN_GRASS: Rgb = (0x8F, 0xB0, 0x4E)
STONE: Rgb = (0x7A, 0x6B, 0x59)
SHADOW_STONE: Rgb = (0x5C, 0x50, 0x46)
LIGHT_STONE: Rgb = (0xA8, 0x98, 0x84)
DARK_TIMBER: Rgb = (0x4A, 0x2F, 0x1A)
PALE_SAND: Rgb = (0xD2, 0xC0, 0x94)
CREVICE: Rgb = (0x3F, 0x2A, 0x26)
DEEP_WATER: Rgb = (0x2A, 0x4E, 0x6E)
MID_WATER: Rgb = (0x3F, 0x6E, 0x94)
HIGHLIGHT_WATER: Rgb = (0x6F, 0xA4, 0xC2)
GLINT: Rgb = (0xA8, 0xCC, 0xDD)
OUTLINE: Rgb = (0x1A, 0x14, 0x10)
CREAM: Rgb = (0xFF, 0xE9, 0xC8)


def _hash01(x: int, y: int, seed: int) -> float:
    """Deterministic per-pixel noise in [0, 1) (splitmix64 finaliser)."""
    z = (x * 0x9E3779B1 + y * 0x85EBCA77 + seed * 0xC2B2AE3D) & 0xFFFFFFFFFFFFFFFF
    z = ((z ^ (z >> 30)) * 0xBF58476D1CE4E5B9) & 0xFFFFFFFFFFFFFFFF
    z = ((z ^ (z >> 27)) * 0x94D049BB133111EB) & 0xFFFFFFFFFFFFFFFF
    z ^= z >> 31
    return (z & 0xFFFFFF) / float(1 << 24)


def _canvas() -> Image.Image:
    return Image.new("RGBA", TILE, (0, 0, 0, 0))


def _paint_diamond(paint: Callable[[int, int], Rgb]) -> Image.Image:
    """Fill every diamond pixel with `paint(x, y)`, then darken the two
    south-facing rims by dithering, so each tile reads as a slab lit
    from the north-west without drawing a hard grid line."""
    width, height = TILE
    img = _canvas()
    px = img.load()
    for y in range(height):
        for x in range(width):
            if in_diamond(x, y, width, height):
                px[x, y] = (*paint(x, y), 255)
    return img


def _shade_south_rims(img: Image.Image, shade: Rgb) -> Image.Image:
    width, height = TILE
    px = img.load()
    for y in range(height):
        for x in range(width):
            if not in_diamond(x, y, width, height):
                continue
            on_rim = not in_diamond(x, y + 1, width, height)
            if on_rim and (x + y) % 2 == 0:
                px[x, y] = (*shade, 255)
    return img


def _clip_to_diamond(img: Image.Image) -> Image.Image:
    width, height = TILE
    px = img.load()
    for y in range(height):
        for x in range(width):
            if not in_diamond(x, y, width, height):
                px[x, y] = (0, 0, 0, 0)
    return img


# ---------------- grass ----------------

def _grass(wind: int) -> Image.Image:
    def paint(x: int, y: int) -> Rgb:
        n = _hash01(x, y, 11)
        if n < 0.16:
            return SHADOW_GREEN
        # Sunlit blade tips sway with the wind frame; shadows stay put.
        if _hash01(x + wind, y, 12) > 0.90:
            return SUN_GRASS
        return LEAF

    img = _paint_diamond(paint)
    px = img.load()
    # Blade strokes: a highlight with its own shadow pixel below.
    width, height = TILE
    for y in range(height - 1):
        for x in range(width):
            inside = in_diamond(x, y, width, height) and in_diamond(x, y + 1, width, height)
            if inside and _hash01(x + wind, y, 13) > 0.975:
                px[x, y] = (*SUN_GRASS, 255)
                px[x, y + 1] = (*SHADOW_GREEN, 255)
    return _shade_south_rims(img, SHADOW_GREEN)


# ---------------- forest ----------------

_TREES = [(22, 12), (36, 9), (45, 16), (29, 19), (39, 21), (17, 17)]


def _tree(px, cx: int, cy: int) -> None:
    width, height = TILE
    # Ground shadow falls south-east.
    for dy in range(-1, 3):
        for dx in range(-3, 5):
            x, y = cx + dx + 2, cy + dy + 4
            if (dx / 4) ** 2 + (dy / 2) ** 2 <= 1 and in_diamond(x, y, width, height):
                px[x, y] = (*DARK_LOAM, 255)
    px[cx, cy + 3] = (*DARK_TIMBER, 255)
    px[cx, cy + 4] = (*DARK_TIMBER, 255)
    rx, ry = 4.5, 3.5
    for dy in range(-4, 4):
        for dx in range(-5, 6):
            d = (dx / rx) ** 2 + (dy / ry) ** 2
            if d > 1:
                continue
            x, y = cx + dx, cy + dy
            if d > 0.72 and (dx > 0 or dy > 0):
                colour = OUTLINE
            elif dx + dy < -3:
                colour = SUN_GRASS
            elif dx + dy > 2:
                colour = SHADOW_GREEN
            else:
                colour = LEAF if _hash01(x, y, 21) > 0.25 else SHADOW_GREEN
            px[x, y] = (*colour, 255)


def _forest() -> Image.Image:
    def paint(x: int, y: int) -> Rgb:
        n = _hash01(x, y, 20)
        if n < 0.10:
            return DARK_LOAM
        return SHADOW_GREEN if n < 0.62 else LEAF

    img = _paint_diamond(paint)
    px = img.load()
    for cx, cy in sorted(_TREES, key=lambda t: t[1]):
        _tree(px, cx, cy)
    return _clip_to_diamond(_shade_south_rims(img, DARK_LOAM))


# ---------------- beach ----------------

def _beach(sparkle: int) -> Image.Image:
    def paint(x: int, y: int) -> Rgb:
        n = _hash01(x, y, 30)
        if n < 0.10:
            return LIGHT_LOAM
        if n > 0.995:
            return STONE
        if _hash01(x, y, 31 + sparkle) > 0.975:
            return CREAM
        return PALE_SAND if n > 0.80 else SAND

    return _shade_south_rims(_paint_diamond(paint), LIGHT_LOAM)


# ---------------- mountain ----------------

# Peaks as (x, y, radius, height). Distance is measured in iso space
# (x halved) so ridges sit flat on the 2:1 tile.
_MOUNTAINS = {
    "terrain-mountain": [(28, 14, 10, 1.0), (42, 18, 7, 0.75)],
    "terrain-mountain-v1": [(24, 15, 8, 0.85), (38, 14, 10, 1.0)],
    "terrain-mountain-v2": [(32, 15, 12, 1.0)],
    "terrain-mountain-v3": [(22, 17, 7, 0.8), (33, 12, 8, 0.95), (44, 18, 6, 0.7)],
}


def _height(peaks: list[tuple[int, int, int, float]], x: float, y: float) -> float:
    best = 0.0
    for px_, py_, radius, peak in peaks:
        d = (((x - px_) / 2) ** 2 + (y - py_) ** 2) ** 0.5 / radius
        best = max(best, peak * max(0.0, 1 - d))
    return best


def _mountain(name: str) -> Image.Image:
    peaks = _MOUNTAINS[name]

    def paint(x: int, y: int) -> Rgb:
        z = _height(peaks, x, y)
        if z <= 0.02:
            n = _hash01(x, y, 40)
            return MEDIUM_LOAM if n < 0.25 else (STONE if n > 0.7 else SHADOW_STONE)
        # Light from the north-west: compare against the pixel up-left.
        slope = z - _height(peaks, x - 2, y - 1)
        if slope > 0.06:
            colour = LIGHT_STONE if z > 0.35 else STONE
        elif slope < -0.06:
            colour = CREVICE if z < 0.2 else SHADOW_STONE
        else:
            colour = STONE
        if z > 0.85 and slope >= 0:
            colour = CREAM if _hash01(x, y, 41) > 0.5 else LIGHT_STONE
        return colour

    return _shade_south_rims(_paint_diamond(paint), CREVICE)


# ---------------- water ----------------

# Wave bands run along `x + 2y` with a 16-pixel period. Adjacent iso
# tiles are offset by (±32, ±16), which shifts `x + 2y` by 0 or 64 —
# both multiples of 16 — so bands continue across tile seams.
_WAVE_PERIOD = 16


def _water(frame: int) -> Image.Image:
    shift = frame * 4

    def paint(x: int, y: int) -> Rgb:
        phase = (x + 2 * y + shift) % _WAVE_PERIOD
        if _hash01(x, y, 50 + frame) > 0.988:
            return GLINT
        if phase in (0, 1):
            return HIGHLIGHT_WATER if _hash01(x, y, 51) > 0.55 else MID_WATER
        if phase in (2, 3, 15):
            return MID_WATER
        return DEEP_WATER if _hash01(x, y, 52) > 0.12 else MID_WATER

    return _paint_diamond(paint)


# ---------------- registry ----------------

_RENDERERS: dict[str, Callable[[], Image.Image]] = {
    "terrain-grass": lambda: _grass(0),
    "terrain-grass-0": lambda: _grass(0),
    "terrain-grass-1": lambda: _grass(3),
    "terrain-forest": _forest,
    "terrain-beach": lambda: _beach(0),
    "terrain-beach-0": lambda: _beach(0),
    "terrain-beach-1": lambda: _beach(1),
    "terrain-water": lambda: _water(0),
    **{f"terrain-water-{i}": (lambda i=i: _water(i)) for i in range(4)},
    **{name: (lambda name=name: _mountain(name)) for name in _MOUNTAINS},
}


def supported() -> list[str]:
    return sorted(_RENDERERS)


def render(sprite_name: str) -> Image.Image:
    """Canonical-size RGBA sprite. Raises KeyError for unknown names."""
    return _RENDERERS[sprite_name]()


def render_sheet(sprite_name: str) -> Image.Image:
    """The sprite upscaled with nearest-neighbour to the square sheet
    size the pipeline's offline path reads from `_sheets/`."""
    return render(sprite_name).resize((SHEET_SIZE, SHEET_SIZE), resample=Image.Resampling.NEAREST)
