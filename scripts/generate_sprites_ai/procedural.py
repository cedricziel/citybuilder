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

from PIL import Image, ImageDraw

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
TIMBER: Rgb = (0x6E, 0x4A, 0x2A)
PINE: Rgb = (0xA0, 0x7C, 0x50)
WHEAT: Rgb = (0xD4, 0xA8, 0x6A)
THATCH: Rgb = (0x8B, 0x5A, 0x2B)


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


# ---------------- farm (2×2 building) ----------------

BUILDING = (128, 128)
# The 2×2 footprint diamond fills the canvas's bottom 64 rows; the
# renderer anchors building sprites at the footprint's bottom vertex.
_FIELD_TOP = 64


def _in_field(x: int, y: int) -> bool:
    return y >= _FIELD_TOP and in_diamond(x, y - _FIELD_TOP, 128, 64)


def _field(stage: str, wind: int) -> Image.Image:
    """Crop rows run along the iso x-axis (down-right). `stage` is one
    of tilled / seedlings / green / ripe."""
    img = Image.new("RGBA", BUILDING, (0, 0, 0, 0))
    px = img.load()
    for y in range(_FIELD_TOP, 128):
        for x in range(128):
            if not _in_field(x, y):
                continue
            row = (x - 2 * y) % 8
            furrow = row in (0, 1)
            n = _hash01(x, y, 60)
            if stage == "tilled" or furrow:
                colour = DARK_LOAM if furrow else (MEDIUM_LOAM if n > 0.3 else LIGHT_LOAM)
            elif stage == "seedlings":
                colour = LEAF if n > 0.78 else MEDIUM_LOAM
            elif stage == "green":
                colour = SUN_GRASS if n > 0.85 else (LEAF if n > 0.25 else SHADOW_GREEN)
            else:
                band = (x + 2 * y + wind * 6) % 24
                if band in (0, 1, 2):
                    colour = CREAM if n > 0.5 else PALE_SAND
                elif row == 2:
                    colour = THATCH
                else:
                    colour = WHEAT if n > 0.12 else PINE
            px[x, y] = (*colour, 255)
    return img


def _barn(img: Image.Image, stage: str) -> None:
    """A small thatched barn on the field's back corner. Box corners
    are iso: footprint diamond centred at (64, 76), 40×20, walls 14 px."""
    draw = ImageDraw.Draw(img)
    cx, cy, hw, hh, wall = 64, 76, 20, 10, 14
    top, right, bottom, left = (cx, cy - hh), (cx + hw, cy), (cx, cy + hh), (cx - hw, cy)
    if stage == "pad":
        draw.polygon([top, right, bottom, left], fill=(*STONE, 255), outline=(*SHADOW_STONE, 255))
        return
    up = (0, -wall)

    def lift(p: tuple[int, int]) -> tuple[int, int]:
        return (p[0] + up[0], p[1] + up[1])

    # Shadow falls south-east onto the field.
    draw.polygon([right, (right[0] + 10, right[1] + 5), (bottom[0] + 10, bottom[1] + 5), bottom],
                 fill=(*DARK_LOAM, 255))
    if stage == "frame":
        for p in (left, bottom, right):
            draw.line([p, lift(p)], fill=(*TIMBER, 255), width=2)
        draw.line([lift(left), lift(bottom), lift(right)], fill=(*TIMBER, 255), width=1)
        return
    # South-west wall (lit) and south-east wall (shaded).
    draw.polygon([left, bottom, lift(bottom), lift(left)], fill=(*WHEAT, 255), outline=(*OUTLINE, 255))
    draw.polygon([bottom, right, lift(right), lift(bottom)], fill=(*PINE, 255), outline=(*OUTLINE, 255))
    for x0, y0 in ((cx - 12, cy + 2), (cx - 5, cy + 5)):
        draw.line([(x0, y0 - 10), (x0, y0)], fill=(*TIMBER, 255))
    draw.rectangle([cx + 6, cy - 1, cx + 10, cy + 6], fill=(*DARK_TIMBER, 255))  # door
    if stage == "walls":
        return
    # Gable roof: ridge runs along the iso x-axis, overhanging walls.
    ridge_a = (left[0] + hw // 2 - 2, left[1] - hh // 2 - wall - 12)
    ridge_b = (bottom[0] + hw // 2 + 2, bottom[1] - hh // 2 - wall - 12)
    eave_l, eave_b, eave_r = (left[0] - 3, left[1] - wall + 1), (bottom[0], bottom[1] - wall + 3), (right[0] + 3, right[1] - wall + 1)
    draw.polygon([eave_l, eave_b, ridge_b, ridge_a], fill=(*THATCH, 255), outline=(*OUTLINE, 255))
    draw.polygon([eave_b, eave_r, (ridge_b[0] + hw // 2, ridge_b[1] - hh // 2 + 2), ridge_b],
                 fill=(*TIMBER, 255), outline=(*OUTLINE, 255))
    draw.line([ridge_a, ridge_b], fill=(*WHEAT, 255))


def _farm(field_stage: str, barn_stage: str, wind: int = 0) -> Image.Image:
    img = _field(field_stage, wind)
    _barn(img, barn_stage)
    return img


# ---------------- road (1×1 building) ----------------

def _road(variant: int) -> Image.Image:
    """Packed-earth road filling the whole diamond, so neighbouring road
    tiles join into one path. Variants add ruts, cobbles or a puddle."""

    def paint(x: int, y: int) -> Rgb:
        n = _hash01(x, y, 70)
        colour = MEDIUM_LOAM if n < 0.22 else (PALE_SAND if n > 0.93 else LIGHT_LOAM)
        if n > 0.985:
            colour = STONE
        if variant == 1 and (x - 2 * y) % 16 in (3, 11):
            colour = MEDIUM_LOAM
        if variant == 2 and _hash01(x // 3, y // 2, 71) > 0.82:
            colour = LIGHT_STONE if (x + y) % 3 else STONE
        if variant == 3 and ((x - 38) / 7) ** 2 + ((y - 17) / 3) ** 2 <= 1:
            colour = MID_WATER if ((x - 37) / 5) ** 2 + ((y - 16) / 2) ** 2 <= 1 else DARK_LOAM
        return colour

    return _shade_south_rims(_paint_diamond(paint), MEDIUM_LOAM)


def _road_stage(stage: int) -> Image.Image:
    """Construction: 0 staked-out track, 1 centre band cleared, 2 bare
    compacted earth."""
    if stage == 2:
        return _shade_south_rims(
            _paint_diamond(lambda x, y: MEDIUM_LOAM if _hash01(x, y, 72) < 0.35 else LIGHT_LOAM), MEDIUM_LOAM
        )
    img = _canvas()
    px = img.load()
    width, height = TILE
    for y in range(height):
        for x in range(width):
            if not in_diamond(x, y, width, height):
                continue
            band = abs((x - 32) / 2 + (y - 16)) <= (4 if stage == 1 else 0)
            if band and _hash01(x, y, 73) > 0.15:
                px[x, y] = (*MEDIUM_LOAM, 255)
    for sx, sy in ((14, 16), (32, 7), (50, 16), (32, 25)):
        px[sx, sy] = (*TIMBER, 255)
        px[sx, sy - 1] = (*TIMBER, 255)
        px[sx, sy - 2] = (*CREAM, 255)
    return img


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
    "building-road": lambda: _road(0),
    **{f"building-road-v{v}": (lambda v=v: _road(v)) for v in (1, 2, 3)},
    **{f"building-road-constructing-{i}": (lambda i=i: _road_stage(i)) for i in range(3)},
    "building-farm": lambda: _farm("ripe", "roof"),
    "building-farm-constructing-0": lambda: _farm("tilled", "pad"),
    "building-farm-constructing-1": lambda: _farm("seedlings", "frame"),
    "building-farm-constructing-2": lambda: _farm("green", "walls"),
    "building-farm-operational-0": lambda: _farm("ripe", "roof", wind=0),
    "building-farm-operational-1": lambda: _farm("ripe", "roof", wind=2),
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


# ---------------- derived operational frames ----------------

def derive_operational(base: Image.Image, frame: int, frame_count: int) -> Image.Image:
    """An operational frame built from the finished base sprite: the
    building stays pixel-identical, and a chimney smoke plume rises
    over the roof. Keeps every frame on one silhouette, so animation
    never shifts or rescales the building."""
    img = base.convert("RGBA").copy()
    bbox = img.getbbox()
    if bbox is None:
        return img
    left, top, right, _ = bbox
    chimney_x = left + (right - left) * 2 // 3
    px = img.load()
    width, height = img.size
    step = 12 / max(frame_count, 1)
    # Three puffs spaced along the plume; each frame lifts them by one
    # step and the plume drifts slightly east, like wind.
    for puff in range(3):
        rise = (puff * 12 / 3 + frame * step) % 12
        cx = chimney_x + int(rise / 4)
        cy = top + 4 - int(rise)
        radius = 1 + puff % 2 + (1 if rise > 6 else 0)
        for dy in range(-radius, radius + 1):
            for dx in range(-radius, radius + 1):
                x, y = cx + dx, cy + dy
                if not (0 <= x < width and 0 <= y < height) or dx * dx + dy * dy > radius * radius:
                    continue
                if dx + dy < 0:
                    colour = CREAM
                elif dx + dy > radius // 2:
                    colour = STONE
                else:
                    colour = LIGHT_STONE
                px[x, y] = (*colour, 255)
    return img
