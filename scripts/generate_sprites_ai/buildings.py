"""Procedural building kit: iso primitives in one register, and every
building composed from them. Spec: `sprite-style-catalog` / One
procedural register for world sprites; design `unify-art-style` D1–D5.

Register rules (also pinned in `world.md` § Building register):
- Light from the north-west: the south-west wall (left on screen) takes
  the material's mid-tone, the south-east wall (right) its shade.
- A 1-px `#1A1410` outline on the shaded wall's outer edges, along the
  bottom of both walls and under roof eaves.
- 10 px per storey; buildings stand on a packed-earth yard covering the
  whole footprint, so they meet the tile grid exactly.
"""

from __future__ import annotations

import math
from collections.abc import Callable
from dataclasses import dataclass

from PIL import Image, ImageDraw

from .palette import (
    CREAM, DARK_LOAM, DARK_TIMBER, FLAG_RED, LIGHT_LOAM, LIGHT_STONE, MEDIUM_LOAM,
    OUTLINE, PALE_SAND, PINE, SHADOW_STONE, SLATE, STONE, SUN_TERRACOTTA, TERRACOTTA,
    THATCH, TIMBER, WHEAT, Rgb,
)

Point = tuple[float, float]

STOREY = 10
STAGES = ("pad", "frame", "walls", "done")


def _hash01(x: int, y: int, seed: int) -> float:
    z = (x * 0x9E3779B1 + y * 0x85EBCA77 + seed * 0xC2B2AE3D) & 0xFFFFFFFFFFFFFFFF
    z = ((z ^ (z >> 30)) * 0xBF58476D1CE4E5B9) & 0xFFFFFFFFFFFFFFFF
    z = ((z ^ (z >> 27)) * 0x94D049BB133111EB) & 0xFFFFFFFFFFFFFFFF
    z ^= z >> 31
    return (z & 0xFFFFFF) / float(1 << 24)


@dataclass(frozen=True)
class Material:
    lit: Rgb
    shade: Rgb


PLASTER = Material(WHEAT, PINE)
TIMBER_WALL = Material(PINE, TIMBER)
STONE_WALL = Material(LIGHT_STONE, STONE)
TILE_ROOF = Material(SUN_TERRACOTTA, TERRACOTTA)
SLATE_ROOF = Material(STONE, SLATE)
THATCH_ROOF = Material(PALE_SAND, THATCH)


class Projector:
    """Maps footprint coordinates (u along +x tiles, v along +y tiles,
    z height in px) to canvas pixels. The canvas is centred on the
    footprint diamond and its bottom row is the diamond's bottom vertex,
    which is where the renderer anchors building sprites."""

    def __init__(self, w: int, h: int, extra: int) -> None:
        self.w, self.h = w, h
        self.width = (w + h) * 32
        self.height = (w + h) * 16 + extra
        self.cx0 = self.width / 2 - (w - h) * 16
        self.cy0 = self.height - (w + h) * 16

    def p(self, u: float, v: float, z: float = 0.0) -> Point:
        return (self.cx0 + (u - v) * 32, self.cy0 + (u + v) * 16 - z)

    def uv(self, x: int, y: int) -> tuple[float, float]:
        """Ground footprint coordinates under pixel (x, y)'s centre."""
        a = (x + 0.5 - self.cx0) / 32
        b = (y + 0.5 - self.cy0) / 16
        return (a + b) / 2, (b - a) / 2


class Canvas:
    """A projector plus an RGBA image and drawing helpers."""

    def __init__(self, w: int, h: int, extra: int) -> None:
        self.proj = Projector(w, h, extra)
        self.img = Image.new("RGBA", (self.proj.width, self.proj.height), (0, 0, 0, 0))
        self.draw = ImageDraw.Draw(self.img)

    def p(self, u: float, v: float, z: float = 0.0) -> Point:
        return self.proj.p(u, v, z)

    def poly(self, pts: list[Point], fill: Rgb) -> None:
        self.draw.polygon([(round(x), round(y)) for x, y in pts], fill=(*fill, 255))

    def line(self, pts: list[Point], fill: Rgb, width: int = 1) -> None:
        self.draw.line([(round(x), round(y)) for x, y in pts], fill=(*fill, 255), width=width)

    def dot(self, pt: Point, fill: Rgb) -> None:
        self.img.putpixel((round(pt[0]), round(pt[1])), (*fill, 255))

    def ground(self, u0: float, v0: float, u1: float, v1: float, paint: Callable[[int, int], Rgb]) -> None:
        """Fill every pixel whose ground point lies in the rectangle."""
        for y in range(self.proj.height):
            for x in range(self.proj.width):
                u, v = self.proj.uv(x, y)
                if u0 <= u <= u1 and v0 <= v <= v1:
                    self.img.putpixel((x, y), (*paint(x, y), 255))


# ---------------- primitives ----------------

def yard(c: Canvas, u0: float = 0, v0: float = 0, u1: float | None = None, v1: float | None = None) -> None:
    """Packed-earth lot under a building, flush with the tile grid."""
    u1 = c.proj.w if u1 is None else u1
    v1 = c.proj.h if v1 is None else v1

    def paint(x: int, y: int) -> Rgb:
        n = _hash01(x, y, 90)
        return MEDIUM_LOAM if n < 0.3 else (PALE_SAND if n > 0.96 else LIGHT_LOAM)

    c.ground(u0, v0, u1, v1, paint)


def shadow(c: Canvas, u0: float, v0: float, u1: float, v1: float, length: float = 0.3) -> None:
    """Contact shadow along the south-east (+u) side."""
    c.poly([c.p(u1, v0), c.p(u1 + length, v0 + length * 0.5), c.p(u1 + length, v1), c.p(u1, v1)], DARK_LOAM)


def box(c: Canvas, u0: float, v0: float, u1: float, v1: float, z1: float, mat: Material, z0: float = 0) -> None:
    """Walls of a block: lit south-west face, shaded south-east face,
    outline on the shaded side and the bottom."""
    left = [c.p(u0, v1, z0), c.p(u1, v1, z0), c.p(u1, v1, z1), c.p(u0, v1, z1)]
    right = [c.p(u1, v1, z0), c.p(u1, v0, z0), c.p(u1, v0, z1), c.p(u1, v1, z1)]
    c.poly(left, mat.lit)
    c.poly(right, mat.shade)
    c.line([c.p(u0, v1, z0), c.p(u1, v1, z0), c.p(u1, v0, z0)], OUTLINE)
    c.line([c.p(u1, v0, z0), c.p(u1, v0, z1)], OUTLINE)
    c.line([c.p(u1, v1, z0), c.p(u1, v1, z1)], OUTLINE)
    c.line([c.p(u0, v1, z0), c.p(u0, v1, z1)], mat.shade)


def flat_top(c: Canvas, u0: float, v0: float, u1: float, v1: float, z: float, fill: Rgb) -> None:
    c.poly([c.p(u0, v0, z), c.p(u1, v0, z), c.p(u1, v1, z), c.p(u0, v1, z)], fill)
    c.line([c.p(u1, v0, z), c.p(u1, v1, z), c.p(u0, v1, z)], OUTLINE)


def _lerp(a: Point, b: Point, t: float) -> Point:
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def _courses(c: Canvas, eave: tuple[Point, Point], ridge: tuple[Point, Point], fill: Rgb, rows: int) -> None:
    for i in range(1, rows):
        t = i / rows
        c.line([_lerp(eave[0], ridge[0], t), _lerp(eave[1], ridge[1], t)], fill)


def gable_roof(c: Canvas, u0: float, v0: float, u1: float, v1: float, z: float, rise: float,
               mat: Material, wall: Material, axis: str = "u", overhang: float = 0.12) -> None:
    """Gable roof over a block. `axis` is the ridge direction."""
    o = overhang
    if axis == "u":
        vm = (v0 + v1) / 2
        back = [c.p(u0 - o, v0 - o, z), c.p(u1 + o, v0 - o, z), c.p(u1 + o, vm, z + rise), c.p(u0 - o, vm, z + rise)]
        c.poly(back, mat.shade)
        c.poly([c.p(u1, v0, z), c.p(u1, v1, z), c.p(u1, vm, z + rise)], wall.shade)
        c.line([c.p(u1, v0, z), c.p(u1, vm, z + rise), c.p(u1, v1, z)], OUTLINE)
        front = [c.p(u0 - o, v1 + o, z), c.p(u1 + o, v1 + o, z), c.p(u1 + o, vm, z + rise), c.p(u0 - o, vm, z + rise)]
        c.poly(front, mat.lit)
        _courses(c, (front[0], front[1]), (front[3], front[2]), mat.shade, 4)
        c.line([front[0], front[1], front[2]], OUTLINE)
        c.line([front[3], front[2]], mat.shade)
    else:
        um = (u0 + u1) / 2
        back = [c.p(u0 - o, v0 - o, z), c.p(u0 - o, v1 + o, z), c.p(um, v1 + o, z + rise), c.p(um, v0 - o, z + rise)]
        c.poly(back, mat.lit)
        c.poly([c.p(u0, v1, z), c.p(u1, v1, z), c.p(um, v1, z + rise)], wall.lit)
        c.line([c.p(u0, v1, z), c.p(um, v1, z + rise)], wall.shade)
        front = [c.p(u1 + o, v0 - o, z), c.p(u1 + o, v1 + o, z), c.p(um, v1 + o, z + rise), c.p(um, v0 - o, z + rise)]
        c.poly(front, mat.shade)
        _courses(c, (front[0], front[1]), (front[3], front[2]), SLATE if mat is not SLATE_ROOF else STONE, 4)
        c.line([front[0], front[1], front[2]], OUTLINE)
        c.line([c.p(u0 - o, v1 + o, z), front[1]], OUTLINE)


def hip_roof(c: Canvas, u0: float, v0: float, u1: float, v1: float, z: float, rise: float, mat: Material,
             overhang: float = 0.12) -> None:
    """Hip roof: ridge along the longer side, sloped ends."""
    o = overhang
    a, b, cc, d = (u0 - o, v0 - o), (u1 + o, v0 - o), (u1 + o, v1 + o), (u0 - o, v1 + o)
    inset = min(u1 - u0, v1 - v0) / 2
    if (u1 - u0) >= (v1 - v0):
        r0, r1 = (u0 + inset, (v0 + v1) / 2), (u1 - inset, (v0 + v1) / 2)
    else:
        r0, r1 = ((u0 + u1) / 2, v0 + inset), ((u0 + u1) / 2, v1 - inset)
    rp0, rp1 = c.p(*r0, z + rise), c.p(*r1, z + rise)
    pa, pb, pc, pd = c.p(*a, z), c.p(*b, z), c.p(*cc, z), c.p(*d, z)
    c.poly([pa, pb, rp1, rp0], mat.shade)
    c.poly([pb, pc, rp1], mat.shade)
    c.poly([pd, pc, rp1, rp0] if (u1 - u0) >= (v1 - v0) else [pd, pc, rp1, rp0], mat.lit)
    c.poly([pa, pd, rp0], mat.lit)
    _courses(c, (pd, pc), (rp0, rp1), mat.shade, 4)
    c.line([pd, pc, pb], OUTLINE)
    c.line([pc, rp1], OUTLINE)
    c.line([rp0, rp1], mat.shade)


def timber_frame(c: Canvas, u0: float, u1: float, v1: float, z0: float, z1: float, step: float = 0.4) -> None:
    """Half-timber posts, a mid rail and braces on the lit wall."""
    t = u0
    while t <= u1 + 1e-6:
        c.line([c.p(t, v1, z0), c.p(t, v1, z1)], TIMBER)
        t += step
    zm = (z0 + z1) / 2
    c.line([c.p(u0, v1, zm), c.p(u1, v1, zm)], TIMBER)
    c.line([c.p(u0, v1, z1), c.p(u1, v1, z1)], DARK_TIMBER)
    c.line([c.p(u0, v1, zm), c.p(u0 + step, v1, z1)], TIMBER)


def window(c: Canvas, face: str, u: float, v: float, z: float, lit: bool = True) -> None:
    x, y = c.p(u, v, z)
    x, y = round(x), round(y)
    frame = CREAM if lit else PINE
    c.draw.rectangle([x - 1, y - 2, x + 1, y + 1], fill=(*frame, 255))
    c.draw.rectangle([x, y - 1, x, y], fill=(*DARK_TIMBER, 255))


def door(c: Canvas, u: float, v: float, z0: float = 0, height: int = 6) -> None:
    x, y = c.p(u, v, z0)
    x, y = round(x), round(y)
    c.draw.rectangle([x - 1, y - height, x + 1, y - 1], fill=(*DARK_TIMBER, 255))
    c.draw.point((x + 1, y - height // 2), fill=(*PINE, 255))


def chimney(c: Canvas, u: float, v: float, z0: float, z1: float) -> None:
    box(c, u, v, u + 0.14, v + 0.14, z1, STONE_WALL, z0=z0)
    flat_top(c, u, v, u + 0.14, v + 0.14, z1, SHADOW_STONE)


def crenellations(c: Canvas, u0: float, v0: float, u1: float, v1: float, z: float) -> None:
    steps = 4
    for i in range(steps):
        t0 = u0 + (u1 - u0) * i / steps
        box(c, t0, v1 - 0.12, t0 + (u1 - u0) / steps / 2, v1, z + 4, STONE_WALL, z0=z)
    for i in range(steps):
        t0 = v0 + (v1 - v0) * i / steps
        box(c, u1 - 0.12, t0, u1, t0 + (v1 - v0) / steps / 2, z + 4, STONE_WALL, z0=z)


def log_pile(c: Canvas, u: float, v: float, rows: int = 3) -> None:
    for r in range(rows):
        for i in range(rows - r):
            x, y = c.p(u + i * 0.12 + r * 0.06, v, 2 + r * 3)
            x, y = round(x), round(y)
            c.draw.ellipse([x - 2, y - 2, x + 1, y + 1], fill=(*PINE, 255), outline=(*DARK_TIMBER, 255))


def crate(c: Canvas, u: float, v: float, s: float = 0.18) -> None:
    box(c, u, v, u + s, v + s, 5, TIMBER_WALL)
    flat_top(c, u, v, u + s, v + s, 5, PINE)


def flag(c: Canvas, u: float, v: float, z: float, height: int = 12) -> None:
    x, y = c.p(u, v, z)
    x, y = round(x), round(y)
    c.line([(x, y), (x, y - height)], DARK_TIMBER)
    c.draw.rectangle([x + 1, y - height, x + 4, y - height + 2], fill=(*FLAG_RED, 255))


def pier(c: Canvas, u0: float, v0: float, u1: float, v1: float) -> None:
    """Plank deck over water at low height, with posts and an outline."""
    deck = 3

    def paint(x: int, y: int) -> Rgb:
        u, v = c.proj.uv(x, y + deck)
        return TIMBER if int((u + v) * 8) % 3 == 0 else PINE

    for y in range(c.proj.height):
        for x in range(c.proj.width):
            u, v = c.proj.uv(x, y + deck)
            if u0 <= u <= u1 and v0 <= v <= v1:
                c.img.putpixel((x, y), (*paint(x, y), 255))
    for u, v in ((u1, v1), (u1, v0), (u0, v1)):
        c.line([c.p(u, v, deck), c.p(u, v, 0)], DARK_TIMBER)
    c.line([c.p(u0, v1, deck), c.p(u1, v1, deck), c.p(u1, v0, deck)], OUTLINE)
    c.line([c.p(u0, v1, 0), c.p(u1, v1, 0), c.p(u1, v0, 0)], OUTLINE)


def scaffold(c: Canvas, u0: float, v0: float, u1: float, v1: float, z1: float) -> None:
    for u in (u0, (u0 + u1) / 2, u1):
        c.line([c.p(u, v1 + 0.1, 0), c.p(u, v1 + 0.1, z1 + 3)], PINE)
    for v in (v0, (v0 + v1) / 2):
        c.line([c.p(u1 + 0.1, v, 0), c.p(u1 + 0.1, v, z1 + 3)], PINE)
    for z in (z1 * 0.4, z1 * 0.8):
        c.line([c.p(u0, v1 + 0.1, z), c.p(u1, v1 + 0.1, z)], TIMBER)
        c.line([c.p(u1 + 0.1, v0, z), c.p(u1 + 0.1, v1, z)], TIMBER)


def frame_posts(c: Canvas, u0: float, v0: float, u1: float, v1: float, z1: float) -> None:
    for u, v in ((u0, v1), (u1, v1), (u1, v0), (u0, v0)):
        c.line([c.p(u, v, 0), c.p(u, v, z1)], TIMBER)
    c.line([c.p(u0, v0, z1), c.p(u1, v0, z1), c.p(u1, v1, z1), c.p(u0, v1, z1), c.p(u0, v0, z1)], DARK_TIMBER)


def pad(c: Canvas, u0: float, v0: float, u1: float, v1: float) -> None:
    box(c, u0, v0, u1, v1, 2, STONE_WALL)
    flat_top(c, u0, v0, u1, v1, 2, LIGHT_STONE)


# ---------------- building composition ----------------

@dataclass(frozen=True)
class Block:
    """The main structure: footprint rectangle, wall height and look."""
    u0: float
    v0: float
    u1: float
    v1: float
    z: float
    wall: Material
    roof: Material
    roof_kind: str = "gable_u"
    rise: float = 12
    framed: bool = False


def draw_block(c: Canvas, b: Block, stage: str) -> None:
    if stage == "pad":
        pad(c, b.u0, b.v0, b.u1, b.v1)
        return
    if stage == "frame":
        pad(c, b.u0, b.v0, b.u1, b.v1)
        frame_posts(c, b.u0, b.v0, b.u1, b.v1, b.z)
        return
    shadow(c, b.u0, b.v0, b.u1, b.v1)
    box(c, b.u0, b.v0, b.u1, b.v1, b.z, b.wall)
    if b.framed:
        timber_frame(c, b.u0, b.u1, b.v1, 0, b.z)
    if stage == "walls":
        flat_top(c, b.u0, b.v0, b.u1, b.v1, b.z, DARK_TIMBER)
        scaffold(c, b.u0, b.v0, b.u1, b.v1, b.z)
        return
    if b.roof_kind == "hip":
        hip_roof(c, b.u0, b.v0, b.u1, b.v1, b.z, b.rise, b.roof)
    elif b.roof_kind == "flat":
        flat_top(c, b.u0, b.v0, b.u1, b.v1, b.z, SHADOW_STONE)
    else:
        gable_roof(c, b.u0, b.v0, b.u1, b.v1, b.z, b.rise, b.roof, b.wall, axis=b.roof_kind[-1])


def _house(stage: str) -> Image.Image:
    c = Canvas(2, 2, 56)
    yard(c)
    b = Block(0.3, 0.3, 1.6, 1.6, 2 * STOREY, PLASTER, TILE_ROOF, "gable_u", 14, framed=True)
    draw_block(c, b, stage)
    if stage in ("walls", "done"):
        door(c, 0.75, 1.6)
        window(c, "left", 1.2, 1.6, 15)
        window(c, "left", 0.5, 1.6, 15)
        window(c, "right", 1.6, 0.9, 13, lit=False)
    if stage == "done":
        chimney(c, 1.2, 0.55, 20, 38)
    return c.img


def _house_tier2() -> Image.Image:
    """Citizens: stone ground floor, half-timbered upper storey."""
    c = Canvas(2, 2, 72)
    yard(c)
    shadow(c, 0.25, 0.25, 1.65, 1.65)
    box(c, 0.25, 0.25, 1.65, 1.65, 12, STONE_WALL)
    box(c, 0.2, 0.2, 1.7, 1.7, 26, PLASTER, z0=12)
    timber_frame(c, 0.2, 1.7, 1.7, 12, 26, step=0.35)
    gable_roof(c, 0.2, 0.2, 1.7, 1.7, 26, 16, TILE_ROOF, PLASTER, axis="u")
    door(c, 0.7, 1.65, height=7)
    for u in (0.45, 1.0, 1.45):
        window(c, "left", u, 1.7, 21)
    window(c, "left", 1.25, 1.65, 7)
    window(c, "right", 1.7, 0.8, 20, lit=False)
    chimney(c, 1.2, 0.5, 26, 46)
    crate(c, 1.75, 1.75)
    return c.img


def _house_tier3() -> Image.Image:
    """Merchants: three storeys of stone and timber under a slate hip
    roof, with two chimneys."""
    c = Canvas(2, 2, 92)
    yard(c)
    shadow(c, 0.15, 0.15, 1.75, 1.75, 0.4)
    box(c, 0.15, 0.15, 1.75, 1.75, 14, STONE_WALL)
    box(c, 0.15, 0.15, 1.75, 1.75, 38, PLASTER, z0=14)
    timber_frame(c, 0.15, 1.75, 1.75, 14, 26, step=0.32)
    timber_frame(c, 0.15, 1.75, 1.75, 26, 38, step=0.32)
    hip_roof(c, 0.15, 0.15, 1.75, 1.75, 38, 18, SLATE_ROOF)
    door(c, 0.6, 1.75, height=8)
    door(c, 0.95, 1.75, height=8)
    for z in (20, 32):
        for u in (0.4, 0.9, 1.4):
            window(c, "left", u, 1.75, z)
        window(c, "right", 1.75, 0.6, z - 1, lit=False)
        window(c, "right", 1.75, 1.2, z - 1, lit=False)
    chimney(c, 0.5, 0.4, 38, 60)
    chimney(c, 1.3, 0.4, 38, 58)
    return c.img


def _bakery(stage: str) -> Image.Image:
    c = Canvas(2, 2, 56)
    yard(c)
    b = Block(0.2, 0.3, 1.35, 1.45, 16, PLASTER, TILE_ROOF, "gable_u", 13, framed=True)
    draw_block(c, b, stage)
    if stage in ("walls", "done"):
        door(c, 0.55, 1.45, height=8)
        window(c, "left", 1.05, 1.45, 11)
    if stage == "done":
        # Domed brick oven against the east wall with its own flue.
        box(c, 1.4, 0.55, 1.85, 1.15, 8, Material(SUN_TERRACOTTA, TERRACOTTA))
        flat_top(c, 1.4, 0.55, 1.85, 1.15, 8, TERRACOTTA)
        x, y = c.p(1.85, 0.85, 4)
        c.draw.rectangle([round(x) - 1, round(y) - 2, round(x) + 1, round(y)], fill=(*OUTLINE, 255))
        chimney(c, 1.55, 0.65, 8, 34)
        for i in range(2):
            crate(c, 0.35 + i * 0.25, 1.6)
    return c.img


def _field_rows(c: Canvas, u0: float, v0: float, u1: float, v1: float, ripe: Rgb, row: Rgb) -> None:
    def paint(x: int, y: int) -> Rgb:
        u, v = c.proj.uv(x, y)
        return row if int(u * 6) % 2 == 0 else (ripe if _hash01(x, y, 95) > 0.15 else row)

    c.ground(u0, v0, u1, v1, paint)


def _grain_farm(stage: str) -> Image.Image:
    c = Canvas(2, 2, 40)
    yard(c)
    if stage != "pad":
        ripe = PALE_SAND if stage == "done" else (WHEAT if stage == "walls" else LIGHT_LOAM)
        _field_rows(c, 0.05, 0.75, 1.95, 1.95, ripe, MEDIUM_LOAM)
        # Low wattle fence along the field's near edges.
        c.line([c.p(0.05, 1.95, 2), c.p(1.95, 1.95, 2), c.p(1.95, 0.75, 2)], OUTLINE)
        c.line([c.p(0.05, 1.95, 0), c.p(1.95, 1.95, 0), c.p(1.95, 0.75, 0)], OUTLINE)
    b = Block(0.25, 0.1, 1.25, 0.65, 10, TIMBER_WALL, THATCH_ROOF, "gable_u", 9)
    draw_block(c, b, stage)
    if stage == "done":
        door(c, 0.6, 0.65, height=6)
        for i in range(3):
            x, y = c.p(1.45 + i * 0.15, 0.4, 0)
            c.poly([(x - 2, y), (x + 2, y), (x, y - 7)], WHEAT)
            c.line([(x - 2, y), (x, y - 7), (x + 2, y)], THATCH)
    return c.img


def _sails(c: Canvas, hub: Point, angle: float) -> None:
    for k in range(4):
        a = angle + k * math.pi / 2
        tip = (hub[0] + math.cos(a) * 26, hub[1] + math.sin(a) * 26)
        mid = (hub[0] + math.cos(a) * 8, hub[1] + math.sin(a) * 8)
        side = (math.cos(a + math.pi / 2) * 4, math.sin(a + math.pi / 2) * 4)
        c.poly([mid, tip, (tip[0] + side[0], tip[1] + side[1]), (mid[0] + side[0], mid[1] + side[1])], PALE_SAND)
        c.line([hub, tip], DARK_TIMBER)
        c.line([(tip[0] + side[0], tip[1] + side[1]), tip], OUTLINE)
    c.draw.ellipse([round(hub[0]) - 2, round(hub[1]) - 2, round(hub[0]) + 2, round(hub[1]) + 2],
                   fill=(*DARK_TIMBER, 255), outline=(*OUTLINE, 255))


def _windmill(stage: str, angle: float = math.pi / 4) -> Image.Image:
    c = Canvas(2, 2, 92)
    yard(c)
    b = Block(0.55, 0.55, 1.45, 1.45, 34, STONE_WALL, THATCH_ROOF, "hip", 20)
    draw_block(c, b, stage)
    if stage in ("walls", "done"):
        door(c, 0.95, 1.45, height=8)
        window(c, "left", 0.8, 1.45, 24)
        window(c, "right", 1.45, 1.0, 22, lit=False)
    if stage == "done":
        _sails(c, c.p(1.0, 1.45, 40), angle)
        crate(c, 0.2, 1.6)
    return c.img


def _mine(stage: str) -> Image.Image:
    c = Canvas(2, 2, 44)
    yard(c)
    if stage == "done":
        # Timbered adit into the slope, an ore heap and a cart track.
        box(c, 0.2, 0.2, 1.1, 0.9, 16, STONE_WALL)
        flat_top(c, 0.2, 0.2, 1.1, 0.9, 16, SHADOW_STONE)
        x, y = c.p(0.65, 0.9, 0)
        c.draw.rectangle([round(x) - 5, round(y) - 11, round(x) + 5, round(y) - 1], fill=(*OUTLINE, 255))
        c.line([(round(x) - 6, round(y)), (round(x) - 6, round(y) - 12), (round(x) + 6, round(y) - 12),
                (round(x) + 6, round(y))], TIMBER, width=2)
        for i in range(5):
            px, py = c.p(1.4 + (i % 3) * 0.12, 1.4 + (i // 3) * 0.12, 2 + (i // 3) * 2)
            c.draw.ellipse([round(px) - 3, round(py) - 2, round(px) + 2, round(py) + 2],
                           fill=(*(SHADOW_STONE if i % 2 else STONE), 255), outline=(*OUTLINE, 255))
        c.line([c.p(0.65, 1.0, 0), c.p(0.65, 1.9, 0)], DARK_TIMBER)
        c.line([c.p(0.8, 1.0, 0), c.p(0.8, 1.9, 0)], DARK_TIMBER)
        crate(c, 0.62, 1.5, 0.2)
    elif stage == "walls":
        box(c, 0.2, 0.2, 1.1, 0.9, 10, STONE_WALL)
        flat_top(c, 0.2, 0.2, 1.1, 0.9, 10, SHADOW_STONE)
    else:
        b = Block(0.2, 0.2, 1.1, 0.9, 16, STONE_WALL, SLATE_ROOF, "flat")
        draw_block(c, b, stage)
    return c.img


def _charcoal_burner(stage: str) -> Image.Image:
    c = Canvas(2, 2, 40)
    yard(c)
    b = Block(0.2, 0.2, 0.95, 0.85, 10, TIMBER_WALL, THATCH_ROOF, "gable_v", 9)
    draw_block(c, b, stage)
    if stage == "done":
        # Turf-covered charcoal clamp.
        x, y = c.p(1.35, 1.35, 0)
        c.draw.ellipse([round(x) - 22, round(y) - 18, round(x) + 22, round(y) + 6],
                       fill=(*DARK_LOAM, 255), outline=(*OUTLINE, 255))
        c.draw.ellipse([round(x) - 16, round(y) - 16, round(x) + 6, round(y) - 6], fill=(*MEDIUM_LOAM, 255))
        log_pile(c, 0.2, 1.6, 2)
    return c.img


def _smelter(stage: str) -> Image.Image:
    c = Canvas(2, 2, 60)
    yard(c)
    b = Block(0.2, 0.35, 1.3, 1.5, 16, STONE_WALL, SLATE_ROOF, "gable_u", 12)
    draw_block(c, b, stage)
    if stage in ("walls", "done"):
        door(c, 0.6, 1.5, height=8)
    if stage == "done":
        box(c, 1.35, 0.4, 1.8, 0.85, 34, STONE_WALL)
        flat_top(c, 1.35, 0.4, 1.8, 0.85, 34, SHADOW_STONE)
        x, y = c.p(1.8, 0.62, 6)
        c.draw.rectangle([round(x) - 2, round(y) - 3, round(x) + 1, round(y)], fill=(*SUN_TERRACOTTA, 255))
        crate(c, 1.5, 1.6)
    return c.img


def _toolsmith(stage: str) -> Image.Image:
    c = Canvas(2, 2, 52)
    yard(c)
    b = Block(0.2, 0.25, 1.4, 1.3, 15, PLASTER, TILE_ROOF, "gable_v", 12, framed=True)
    draw_block(c, b, stage)
    if stage in ("walls", "done"):
        door(c, 0.6, 1.3, height=8)
        window(c, "left", 1.1, 1.3, 10)
    if stage == "done":
        chimney(c, 0.5, 0.4, 15, 34)
        # Anvil on a block under a lean-to.
        x, y = c.p(1.7, 1.2, 0)
        c.draw.rectangle([round(x) - 2, round(y) - 5, round(x) + 2, round(y)], fill=(*DARK_TIMBER, 255))
        c.draw.rectangle([round(x) - 4, round(y) - 8, round(x) + 4, round(y) - 6], fill=(*SHADOW_STONE, 255),
                         outline=(*OUTLINE, 255))
    return c.img


def _library(stage: str) -> Image.Image:
    """Stone hall with tall arched windows under a slate roof and a
    small bell turret."""
    c = Canvas(2, 2, 70)
    yard(c)
    b = Block(0.2, 0.3, 1.75, 1.6, 24, STONE_WALL, SLATE_ROOF, "gable_u", 16)
    draw_block(c, b, stage)
    if stage in ("walls", "done"):
        door(c, 0.5, 1.6, height=10)
        for u in (0.9, 1.25, 1.6):
            x, y = c.p(u, 1.6, 8)
            c.draw.rectangle([round(x) - 1, round(y) - 11, round(x) + 1, round(y)], fill=(*DARK_TIMBER, 255))
            c.draw.point((round(x), round(y) - 12), fill=(*DARK_TIMBER, 255))
        window(c, "right", 1.75, 0.9, 16, lit=False)
    if stage == "done":
        box(c, 0.85, 0.8, 1.15, 1.1, 50, STONE_WALL, z0=30)
        hip_roof(c, 0.85, 0.8, 1.15, 1.1, 50, 10, SLATE_ROOF, overhang=0.05)
    return c.img


def _warehouse(stage: str) -> Image.Image:
    c = Canvas(3, 3, 60)
    yard(c)
    b = Block(0.35, 0.35, 2.4, 2.25, 24, STONE_WALL, SLATE_ROOF, "hip", 18)
    draw_block(c, b, stage)
    if stage in ("walls", "done"):
        # Half-timbered upper storey over the stone ground floor.
        box(c, b.u0, b.v0, b.u1, b.v1, b.z, PLASTER, z0=12)
        timber_frame(c, b.u0, b.u1, b.v1, 12, b.z, step=0.35)
        if stage == "done":
            hip_roof(c, b.u0, b.v0, b.u1, b.v1, b.z, b.rise, b.roof)
        for u in (0.9, 1.7):
            door(c, u, 2.25, height=10)
        for u in (0.6, 1.3, 2.0):
            window(c, "left", u, 2.25, 20)
        window(c, "right", 2.4, 1.2, 19, lit=False)
        window(c, "right", 2.4, 0.7, 19, lit=False)
        crate(c, 2.55, 2.45)
        crate(c, 2.6, 2.7)
        crate(c, 0.5, 2.55)
    return c.img


def _lumberjack(stage: str) -> Image.Image:
    c = Canvas(2, 2, 40)
    yard(c)
    b = Block(0.2, 0.2, 1.2, 1.1, 12, TIMBER_WALL, THATCH_ROOF, "gable_v", 12)
    draw_block(c, b, stage)
    if stage in ("walls", "done"):
        door(c, 0.6, 1.1, height=6)
    if stage == "done":
        log_pile(c, 1.25, 1.75)
        box(c, 1.55, 0.6, 1.75, 0.8, 4, TIMBER_WALL)
        flat_top(c, 1.55, 0.6, 1.75, 0.8, 4, WHEAT)
    return c.img


def _sawmill(stage: str) -> Image.Image:
    c = Canvas(2, 2, 52)
    yard(c)
    b = Block(0.2, 0.25, 1.7, 1.35, 16, TIMBER_WALL, SLATE_ROOF, "gable_v", 14, framed=True)
    draw_block(c, b, stage)
    if stage in ("walls", "done"):
        door(c, 0.5, 1.35, height=9)
        window(c, "left", 1.2, 1.35, 11)
    if stage == "done":
        for i in range(3):
            box(c, 0.4 + i * 0.05, 1.55, 1.3, 1.8, 2 + i * 2, Material(WHEAT, PINE), z0=i * 2)
        x, y = c.p(1.75, 0.8, 9)
        c.draw.ellipse([round(x) - 4, round(y) - 4, round(x) + 4, round(y) + 4],
                       fill=(*STONE, 255), outline=(*OUTLINE, 255))
        c.dot((x, y), LIGHT_STONE)
    return c.img


def _town_center(stage: str) -> Image.Image:
    c = Canvas(3, 3, 88)
    yard(c)
    hall = Block(0.3, 0.6, 2.2, 2.6, 22, STONE_WALL, TILE_ROOF, "hip", 16)
    tower = Block(1.85, 0.3, 2.7, 1.15, 46, STONE_WALL, SLATE_ROOF, "flat")
    draw_block(c, tower, stage)
    draw_block(c, hall, stage)
    if stage in ("walls", "done"):
        door(c, 1.2, 2.6, height=10)
        for u in (0.6, 1.8):
            window(c, "left", u, 2.6, 15)
        window(c, "right", 2.7, 0.7, 36, lit=False)
    if stage == "done":
        crenellations(c, 1.85, 0.3, 2.7, 1.15, 46)
        flag(c, 2.3, 0.75, 50, 14)
    return c.img


# Shore buildings: footprint 2×3. The sea side follows the orientation
# name in tile space (e = +u, w = −u, s = +v, n = −v).
_SEA = {"e": (1.0, 0.0, 2.0, 3.0), "w": (0.0, 0.0, 1.0, 3.0), "s": (0.0, 2.0, 2.0, 3.0), "n": (0.0, 0.0, 2.0, 1.0)}
_LAND = {"e": (0.0, 0.0, 1.0, 3.0), "w": (1.0, 0.0, 2.0, 3.0), "s": (0.0, 0.0, 2.0, 2.0), "n": (0.0, 1.0, 2.0, 3.0)}


def _inset(r: tuple[float, float, float, float], d: float) -> tuple[float, float, float, float]:
    return r[0] + d, r[1] + d, r[2] - d, r[3] - d


def _port(orientation: str, stage: str) -> Image.Image:
    c = Canvas(2, 3, 60)
    land, sea = _LAND[orientation], _SEA[orientation]
    yard(c, *land)
    pier(c, *sea)
    u0, v0, u1, v1 = _inset(land, 0.18)
    b = Block(u0, v0, u1, v1, 18, TIMBER_WALL, SLATE_ROOF, "gable_v" if u1 - u0 < v1 - v0 else "gable_u", 12)
    draw_block(c, b, stage)
    if stage in ("walls", "done"):
        door(c, (u0 + u1) / 2, v1, height=8)
    if stage == "done":
        su = (sea[0] + sea[2]) / 2
        sv = (sea[1] + sea[3]) / 2
        crate(c, su - 0.2, sv - 0.2)
        crate(c, su + 0.05, sv + 0.1)
        x, y = c.p(su + 0.3, sv - 0.3, 3)
        c.line([(round(x), round(y)), (round(x), round(y) - 22)], DARK_TIMBER)
        c.line([(round(x), round(y) - 22), (round(x) + 9, round(y) - 18)], DARK_TIMBER)
        c.line([(round(x) + 9, round(y) - 18), (round(x) + 9, round(y) - 10)], OUTLINE)
    return c.img


def _shipyard(orientation: str, stage: str) -> Image.Image:
    c = Canvas(2, 3, 60)
    land, sea = _LAND[orientation], _SEA[orientation]
    yard(c, *land)
    pier(c, *sea)
    u0, v0, u1, v1 = _inset(land, 0.22)
    b = Block(u0, v0, u1, v1, 14, TIMBER_WALL, THATCH_ROOF, "gable_v" if u1 - u0 < v1 - v0 else "gable_u", 11)
    draw_block(c, b, stage)
    if stage in ("walls", "done"):
        door(c, (u0 + u1) / 2, v1, height=8)
    if stage != "pad":
        # Hull ribs on the slipway, growing with the stages.
        su0, sv0, su1, sv1 = _inset(sea, 0.2)
        ribs = {"frame": 3, "walls": 5, "done": 7}[stage]
        along_u = (su1 - su0) >= (sv1 - sv0)
        for i in range(ribs):
            t = i / 6
            if along_u:
                base = c.p(su0 + (su1 - su0) * t, (sv0 + sv1) / 2, 3)
            else:
                base = c.p((su0 + su1) / 2, sv0 + (sv1 - sv0) * t, 3)
            x, y = round(base[0]), round(base[1])
            c.draw.arc([x - 5, y - 9, x + 5, y + 1], 0, 180, fill=(*DARK_TIMBER, 255))
        if stage == "done":
            a = c.p(su0, (sv0 + sv1) / 2, 3) if along_u else c.p((su0 + su1) / 2, sv0, 3)
            z = c.p(su1, (sv0 + sv1) / 2, 3) if along_u else c.p((su0 + su1) / 2, sv1, 3)
            c.line([a, z], OUTLINE)
    return c.img


FOOTPRINTS: dict[str, tuple[int, int]] = {
    "house": (2, 2), "warehouse": (3, 3), "lumberjack-hut": (2, 2), "sawmill": (2, 2),
    "town-center": (3, 3), "bakery": (2, 2), "grain-farm": (2, 2), "windmill": (2, 2), "mine": (2, 2),
    "charcoal-burner": (2, 2), "smelter": (2, 2), "toolsmith": (2, 2), "library": (2, 2), **{f"port-{o}": (2, 3) for o in "nesw"}, **{f"shipyard-{o}": (2, 3) for o in "nesw"},
}

_DRAWERS: dict[str, Callable[[str], Image.Image]] = {
    "house": _house,
    "warehouse": _warehouse,
    "lumberjack-hut": _lumberjack,
    "sawmill": _sawmill,
    "town-center": _town_center,
    "bakery": _bakery,
    "grain-farm": _grain_farm,
    "windmill": _windmill,
    "mine": _mine,
    "charcoal-burner": _charcoal_burner,
    "smelter": _smelter,
    "toolsmith": _toolsmith,
    "library": _library,
    **{f"port-{o}": (lambda stage, o=o: _port(o, stage)) for o in "nesw"},
    **{f"shipyard-{o}": (lambda stage, o=o: _shipyard(o, stage)) for o in "nesw"},
}

OPERATIONAL_FRAMES: dict[str, int] = {
    "lumberjack-hut": 2, "sawmill": 4, "town-center": 2, "bakery": 2, "grain-farm": 2, "windmill": 4,
    "mine": 2, "charcoal-burner": 2, "smelter": 2, "toolsmith": 2, "library": 2,
    **{f"port-{o}": 2 for o in "nesw"}, **{f"shipyard-{o}": 2 for o in "nesw"},
}


# Upgraded house looks, keyed by tier; tier 1 is the plain house.
TIER_HOUSES: dict[int, Callable[[], Image.Image]] = {2: _house_tier2, 3: _house_tier3}


def draw_windmill_frame(frame: int, frames: int) -> Image.Image:
    """Operational windmill frame: the sails turn a quarter turn per cycle."""
    img = _windmill("done", math.pi / 4 + frame * (math.pi / 2) / frames)
    top = _windmill("done").getbbox()[1]
    return img.crop((0, max(0, top - HEADROOM), img.width, img.height))


def draw_house_tier(tier: int) -> Image.Image:
    img = TIER_HOUSES[tier]()
    return img.crop((0, max(0, img.getbbox()[1] - HEADROOM), img.width, img.height))


# Room kept above the tallest pixel for the derived smoke plume.
HEADROOM = 14


def draw(kind: str, stage: str = "done") -> Image.Image:
    """The building at `stage`, with empty canvas above the finished
    building's top trimmed off (the bottom anchor is unchanged)."""
    img = _DRAWERS[kind](stage)
    top = _DRAWERS[kind]("done").getbbox()[1]
    return img.crop((0, max(0, top - HEADROOM), img.width, img.height))
