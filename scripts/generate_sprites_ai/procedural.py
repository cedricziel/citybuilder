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

SHEET_SCALE = 8
TILE = (64, 32)

from .palette import (  # noqa: E402
    CREAM, CREVICE, DARK_LOAM, DARK_TIMBER, DEEP_WATER, GLINT, HIGHLIGHT_WATER, LEAF,
    LIGHT_LOAM, LIGHT_STONE, MEDIUM_LOAM, MID_WATER, OUTLINE, PALE_SAND, PINE, SAND,
    SHADOW_GREEN, SHADOW_STONE, STONE, SUN_GRASS, TERRACOTTA, THATCH, TIMBER, Rgb,
)

WHEAT = (0xD4, 0xA8, 0x6A)


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


def _bread_icon() -> Image.Image:
    """24×24 loaf: golden crust lit from the north-west, darker base,
    cream score marks, outlined."""
    img = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.ellipse([2, 6, 21, 19], fill=(*THATCH, 255), outline=(*OUTLINE, 255))
    draw.ellipse([3, 6, 20, 16], fill=(*WHEAT, 255))
    draw.ellipse([5, 7, 13, 11], fill=(*CREAM, 255))
    for x in (8, 12, 16):
        draw.line([(x - 1, 13), (x + 1, 9)], fill=(*PINE, 255))
    return img


def _icon() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    img = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def _grain_icon() -> Image.Image:
    img, d = _icon()
    for dx in (-5, 0, 5):
        d.line([(12 + dx, 21), (12 + dx // 2, 6)], fill=(*THATCH, 255), width=2)
        d.ellipse([10 + dx // 2, 3, 15 + dx // 2, 11], fill=(*WHEAT, 255), outline=(*OUTLINE, 255))
    d.rectangle([7, 15, 17, 17], fill=(*PINE, 255), outline=(*OUTLINE, 255))
    return img


def _flour_icon() -> Image.Image:
    img, d = _icon()
    d.polygon([(6, 21), (18, 21), (19, 9), (15, 5), (9, 5), (5, 9)], fill=(*PALE_SAND, 255), outline=(*OUTLINE, 255))
    d.line([(9, 5), (12, 8), (15, 5)], fill=(*THATCH, 255))
    d.ellipse([9, 12, 15, 17], fill=(*CREAM, 255))
    return img


def _ore_icon() -> Image.Image:
    img, d = _icon()
    d.polygon([(3, 19), (7, 9), (13, 6), (20, 10), (21, 19)], fill=(*STONE, 255), outline=(*OUTLINE, 255))
    d.polygon([(7, 9), (13, 6), (12, 12)], fill=(*LIGHT_STONE, 255))
    for x, y in ((9, 14), (15, 12), (16, 16)):
        d.rectangle([x, y, x + 2, y + 1], fill=(*TERRACOTTA, 255))
    return img


def _charcoal_icon() -> Image.Image:
    img, d = _icon()
    for x0, y0 in ((3, 12), (11, 12), (7, 6)):
        d.rectangle([x0, y0, x0 + 9, y0 + 6], fill=(*DARK_LOAM, 255), outline=(*OUTLINE, 255))
        d.line([(x0 + 1, y0 + 1), (x0 + 7, y0 + 1)], fill=(*MEDIUM_LOAM, 255))
    return img


def _iron_icon() -> Image.Image:
    img, d = _icon()
    for y0 in (14, 8):
        d.polygon([(4, y0 + 6), (20, y0 + 6), (17, y0), (7, y0)], fill=(*SHADOW_STONE, 255), outline=(*OUTLINE, 255))
        d.line([(8, y0 + 1), (16, y0 + 1)], fill=(*LIGHT_STONE, 255))
    return img


def _tools_icon() -> Image.Image:
    img, d = _icon()
    d.line([(5, 20), (15, 8)], fill=(*TIMBER, 255), width=3)
    d.polygon([(12, 4), (20, 7), (18, 11), (11, 8)], fill=(*SHADOW_STONE, 255), outline=(*OUTLINE, 255))
    d.line([(19, 20), (9, 9)], fill=(*PINE, 255), width=2)
    d.rectangle([6, 5, 10, 9], fill=(*LIGHT_STONE, 255), outline=(*OUTLINE, 255))
    return img


_CHAIN_ICONS = {
    "grain": _grain_icon, "flour": _flour_icon, "ore": _ore_icon,
    "charcoal": _charcoal_icon, "iron": _iron_icon, "tools": _tools_icon,
}


def _register_buildings_and_units() -> None:
    from . import buildings, units

    stages = ("pad", "frame", "walls")
    for kind in buildings.FOOTPRINTS:
        name = f"building-{kind}"
        _RENDERERS[name] = lambda kind=kind: buildings.draw(kind)
        for i, stage in enumerate(stages):
            _RENDERERS[f"{name}-constructing-{i}"] = lambda kind=kind, stage=stage: buildings.draw(kind, stage)
        frames = buildings.OPERATIONAL_FRAMES.get(kind, 0)
        for i in range(frames):
            if kind == "windmill":
                _RENDERERS[f"{name}-operational-{i}"] = lambda i=i, frames=frames: buildings.draw_windmill_frame(i, frames)
                continue
            _RENDERERS[f"{name}-operational-{i}"] = (
                lambda kind=kind, i=i, frames=frames: derive_operational(buildings.draw(kind), i, frames)
            )
    for tier in buildings.TIER_HOUSES:
        _RENDERERS[f"building-house-tier{tier}"] = lambda tier=tier: buildings.draw_house_tier(tier)
    _RENDERERS["good-bread"] = _bread_icon
    for good, draw in _CHAIN_ICONS.items():
        _RENDERERS[f"good-{good}"] = draw
    for facing in ("ne", "se", "sw", "nw"):
        for frame in (0, 1):
            _RENDERERS[f"walker-{facing}-{frame}"] = lambda facing=facing, frame=frame: units.walker(facing, frame)
    for facing in ("n", "ne", "e", "se", "s", "sw", "w", "nw"):
        for frame in (0, 1):
            _RENDERERS[f"ship-{facing}-{frame}"] = lambda facing=facing, frame=frame: units.ship(facing, frame)


def supported() -> list[str]:
    return sorted(_RENDERERS)


def render(sprite_name: str) -> Image.Image:
    """Canonical-size RGBA sprite. Raises KeyError for unknown names."""
    return _RENDERERS[sprite_name]()


def size(sprite_name: str) -> tuple[int, int]:
    """Canonical canvas size; procedural sprites own their size."""
    return render(sprite_name).size


def render_sheet(sprite_name: str) -> Image.Image:
    """The sprite upscaled by an integer factor with nearest-neighbour,
    so the offline path's downsample reproduces it exactly whatever its
    aspect ratio."""
    img = render(sprite_name)
    return img.resize((img.width * SHEET_SCALE, img.height * SHEET_SCALE), resample=Image.Resampling.NEAREST)


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


_register_buildings_and_units()
