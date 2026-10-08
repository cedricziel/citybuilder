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
    CREAM, DARK_LOAM, DARK_TIMBER, DEEP_WATER, FLAG_RED, HIGHLIGHT_WATER, LEAF, LIGHT_LOAM, LIGHT_STONE,
    MEDIUM_LOAM, MID_WATER, OUTLINE, PALE_SAND, PINE, SAND, SHADOW_GREEN, SHADOW_STONE, SLATE, STONE,
    SUN_GRASS, SUN_TERRACOTTA, TERRACOTTA, THATCH, TIMBER, WHEAT, Rgb,
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


# ---------------- culture primitives ----------------

def posts(c: Canvas, u0: float, v0: float, u1: float, v1: float, z0: float, z1: float, fill: Rgb,
          step: float = 0.45) -> None:
    """Exposed posts on both visible walls, a sill and a head beam: the
    post-and-beam frame of East Asian halls."""
    n = max(1, round((u1 - u0) / step))
    for i in range(n + 1):
        u = u0 + (u1 - u0) * i / n
        c.line([c.p(u, v1, z0), c.p(u, v1, z1)], fill)
    n = max(1, round((v1 - v0) / step))
    for i in range(n):
        v = v0 + (v1 - v0) * i / n
        c.line([c.p(u1, v, z0), c.p(u1, v, z1)], fill)
    c.line([c.p(u0, v1, z1), c.p(u1, v1, z1), c.p(u1, v0, z1)], fill)
    c.line([c.p(u0, v1, z0 + 1), c.p(u1, v1, z0 + 1), c.p(u1, v0, z0 + 1)], fill)
    c.line([c.p(u1, v1, z0), c.p(u1, v1, z1)], OUTLINE)


def flared_roof(c: Canvas, u0: float, v0: float, u1: float, v1: float, z: float, rise: float, mat: Material,
                overhang: float = 0.22, lift: float = 3, finial: bool = False) -> None:
    """Hip roof with wide eaves whose corners turn up: each eave edge is
    a curve `lift` px higher at the corners than at its middle."""
    o = overhang
    a, b, cc, d = (u0 - o, v0 - o), (u1 + o, v0 - o), (u1 + o, v1 + o), (u0 - o, v1 + o)
    inset = min(u1 - u0, v1 - v0) / 2
    if (u1 - u0) >= (v1 - v0):
        r0, r1 = (u0 + inset, (v0 + v1) / 2), (u1 - inset, (v0 + v1) / 2)
    else:
        r0, r1 = ((u0 + u1) / 2, v0 + inset), ((u0 + u1) / 2, v1 - inset)
    rp0, rp1 = c.p(*r0, z + rise), c.p(*r1, z + rise)

    def edge(p: tuple[float, float], q: tuple[float, float], n: int = 16) -> list[Point]:
        out = []
        for i in range(n + 1):
            t = i / n
            out.append(c.p(p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t, z + lift * (2 * t - 1) ** 2))
        return out

    back, right, front, left = edge(a, b), edge(b, cc), edge(d, cc), edge(a, d)
    c.poly(back + [rp1, rp0], mat.shade)
    c.poly(right + [rp1], mat.shade)
    c.poly(front + [rp1, rp0], mat.lit)
    c.poly(left + [rp0], mat.lit)
    n = len(front) - 1
    for k in (1, 2, 3):
        t = k / 4
        course = [_lerp(pt, _lerp(rp0, rp1, i / n), t) for i, pt in enumerate(front)]
        c.line(course, mat.shade)
    c.line(front, OUTLINE)
    c.line(right, OUTLINE)
    c.line([front[-1], rp1], OUTLINE)
    c.line([rp0, rp1], OUTLINE)
    if finial:
        x, y = round(rp1[0]), round(rp1[1])
        c.line([(x, y), (x, y - 6)], DARK_TIMBER)
        c.dot((x, y - 3), WHEAT)
        c.dot((x, y - 5), WHEAT)
    else:
        for rp, dx in ((rp0, -1), (rp1, 1)):
            x, y = round(rp[0]), round(rp[1])
            c.line([(x, y), (x + dx, y - 2)], OUTLINE)


def stacked_roofs(c: Canvas, cu: float, cv: float, halves: list[float], walls: list[float], rises: list[float],
                  wall: Material, roof: Material, post: Rgb, z0: float = 0, overhang: float = 0.24,
                  lift: float = 4) -> float:
    """A pagoda: storeys of shrinking size, each under its own flared
    roof; the next storey rises out of the roof below. Returns the top."""
    z = z0
    for i, (h, wh, r) in enumerate(zip(halves, walls, rises)):
        u0, v0, u1, v1 = cu - h, cv - h, cu + h, cv + h
        box(c, u0, v0, u1, v1, z + wh, wall, z0=z)
        posts(c, u0, v0, u1, v1, z, z + wh, post, step=h)
        last = i == len(halves) - 1
        flared_roof(c, u0, v0, u1, v1, z + wh, r, roof, overhang=overhang, lift=lift, finial=last)
        if not last:
            # The next storey stands where the roof slope meets its walls.
            nxt = halves[i + 1]
            z = z + wh + r * (h - nxt + overhang) / (h + overhang)
    return z


def parapet(c: Canvas, u0: float, v0: float, u1: float, v1: float, z: float, mat: Material,
            height: float = 3, rim: float = 0.07, cap: Rgb = PALE_SAND, deck: Rgb = PINE) -> None:
    """Flat roof behind a raised rim: the deck sits at `z`, the rim
    rises `height` px above it on all four sides."""
    zt = z + height
    ui0, vi0, ui1, vi1 = u0 + rim, v0 + rim, u1 - rim, v1 - rim
    c.poly([c.p(u0, v0, zt), c.p(u1, v0, zt), c.p(u1, v1, zt), c.p(u0, v1, zt)], cap)
    c.poly([c.p(ui0, vi0, z), c.p(ui1, vi0, z), c.p(ui1, vi1, z), c.p(ui0, vi1, z)], deck)
    # Inner faces of the back rims: the north rim faces south-west (lit),
    # the west rim faces south-east (shade).
    c.poly([c.p(ui0, vi0, z), c.p(ui1, vi0, z), c.p(ui1, vi0, zt), c.p(ui0, vi0, zt)], mat.lit)
    c.poly([c.p(ui0, vi0, z), c.p(ui0, vi1, z), c.p(ui0, vi1, zt), c.p(ui0, vi0, zt)], mat.shade)
    # Front rims: their outer faces and caps hide the deck's near edge.
    c.poly([c.p(u0, v1, z), c.p(u1, v1, z), c.p(u1, v1, zt), c.p(u0, v1, zt)], mat.lit)
    c.poly([c.p(u1, v1, z), c.p(u1, v0, z), c.p(u1, v0, zt), c.p(u1, v1, zt)], mat.shade)
    c.poly([c.p(u0, vi1, zt), c.p(u1, vi1, zt), c.p(u1, v1, zt), c.p(u0, v1, zt)], cap)
    c.poly([c.p(ui1, v0, zt), c.p(u1, v0, zt), c.p(u1, v1, zt), c.p(ui1, v1, zt)], cap)
    c.line([c.p(u1, v0, z), c.p(u1, v0, zt), c.p(u1, v1, zt), c.p(u0, v1, zt)], OUTLINE)
    c.line([c.p(u1, v1, z), c.p(u1, v1, zt)], OUTLINE)
    c.line([c.p(u0, v1, z), c.p(u0, v1, zt)], mat.shade)


def dome(c: Canvas, u: float, v: float, z: float, radius: float, drum: float, mat: Material,
         drum_mat: Material, height: float | None = None, band: Rgb | None = None) -> None:
    """A dome: a shaded half-ellipse on a cylindrical drum, centred on
    footprint point (u, v) with the drum standing at height `z`."""
    cx, cy = c.p(u, v, z)
    r, ry = radius, radius / 2
    hgt = radius * 1.05 if height is None else height
    top = cy - drum
    px = c.img.load()
    W, H = c.img.size
    x0, x1 = int(cx - r) - 1, int(cx + r) + 2
    y0, y1 = int(top - hgt) - 1, int(cy + ry) + 2

    def in_drum(x: float, y: float) -> bool:
        dx = (x - cx) / r
        if abs(dx) > 1:
            return False
        e = ry * math.sqrt(1 - dx * dx)
        return top - e <= y <= cy + e

    def in_dome(x: float, y: float) -> bool:
        dx = (x - cx) / r
        dy = y - top
        if dy <= 0:
            return dx * dx + (dy / hgt) ** 2 <= 1
        return dx * dx + (dy / ry) ** 2 <= 1

    for y in range(max(0, y0), min(H, y1)):
        for x in range(max(0, x0), min(W, x1)):
            fx, fy = x + 0.5, y + 0.5
            if in_dome(fx, fy):
                nx, ny = (fx - cx) / r, (fy - top) / hgt
                colour = mat.shade if nx + 0.45 * ny > 0.1 else mat.lit
                edge_r = not in_dome(fx + 1, fy) or not in_dome(fx, fy + 1)
                edge_l = not in_dome(fx - 1, fy) or not in_dome(fx, fy - 1)
                if edge_r and (nx > -0.2 or ny > 0):
                    colour = OUTLINE
                elif edge_l:
                    colour = mat.shade
            elif in_drum(fx, fy):
                nx = (fx - cx) / r
                colour = drum_mat.shade if nx > 0.25 else drum_mat.lit
                if band is not None and abs(fy - (top + ry * math.sqrt(max(0.0, 1 - nx * nx)) + 1)) < 1:
                    colour = band
                if not in_drum(fx + 1, fy) or not in_drum(fx, fy + 1):
                    colour = OUTLINE
            else:
                continue
            px[x, y] = (*colour, 255)
    # Finial.
    tx, ty = round(cx), round(top - hgt)
    c.line([(tx, ty), (tx, ty - 4)], DARK_TIMBER)
    c.dot((tx, ty - 4), WHEAT)
    c.dot((tx, ty - 2), WHEAT)


def arch(c: Canvas, x: int, y: int, w: int, h: int, fill: Rgb) -> None:
    """A round-headed opening `w` px wide, its sill at row `y`."""
    hw = w // 2
    c.draw.rectangle([x - hw, y - h + 1, x + hw, y], fill=(*fill, 255))
    c.draw.line([(x - hw + 1, y - h), (x + hw - 1, y - h)], fill=(*fill, 255))
    if w >= 5:
        c.draw.line([(x - hw + 2, y - h - 1), (x + hw - 2, y - h - 1)], fill=(*fill, 255))


def amphora(c: Canvas, u: float, v: float) -> None:
    x, y = c.p(u, v, 0)
    x, y = round(x), round(y)
    c.draw.ellipse([x - 2, y - 6, x + 2, y], fill=(*SUN_TERRACOTTA, 255), outline=(*OUTLINE, 255))
    c.draw.line([(x - 1, y - 7), (x + 1, y - 7)], fill=(*TERRACOTTA, 255))
    c.dot((x - 1, y - 4), CREAM)


def sack(c: Canvas, u: float, v: float) -> None:
    x, y = c.p(u, v, 0)
    x, y = round(x), round(y)
    c.draw.ellipse([x - 3, y - 5, x + 3, y], fill=(*PALE_SAND, 255), outline=(*OUTLINE, 255))
    c.draw.line([(x - 1, y - 5), (x + 1, y - 5)], fill=(*SAND, 255))


def bale(c: Canvas, u: float, v: float) -> None:
    """A straw rice bale, banded."""
    x, y = c.p(u, v, 0)
    x, y = round(x), round(y)
    c.draw.ellipse([x - 3, y - 6, x + 3, y], fill=(*WHEAT, 255), outline=(*OUTLINE, 255))
    c.draw.line([(x - 2, y - 3), (x + 2, y - 3)], fill=(*THATCH, 255))


def mashrabiya(c: Canvas, u: float, v: float, z: float, half: float = 0.16, height: float = 8) -> None:
    """A projecting wooden lattice bay on the lit wall."""
    box(c, u - half, v, u + half, v + 0.1, z + height, TIMBER_WALL, z0=z)
    flat_top(c, u - half, v, u + half, v + 0.1, z + height, DARK_TIMBER)
    x0, y0 = c.p(u - half, v + 0.1, z)
    x1, _ = c.p(u + half, v + 0.1, z)
    for x in range(round(x0) + 1, round(x1)):
        yb = y0 + (x - x0) * 0.5
        for k in range(2, int(height) - 1):
            if (x + k) % 2 == 0:
                c.dot((x, yb - k), DARK_TIMBER)


def palm(c: Canvas, u: float, v: float, height: int = 22) -> None:
    """A date palm: a leaning trunk and a crown of drooping fronds."""
    x, y = _px(c, u, v, 0)
    top = (x + 3, y - height)
    c.line([(x, y), (x + 1, y - height // 2), top], TIMBER, width=2)
    c.line([(x + 1, y), (x + 2, y - height // 2), (top[0] + 1, top[1])], DARK_TIMBER)
    for dx, dy, fill in ((-9, 4, LEAF), (9, 5, SHADOW_GREEN), (-7, -2, SUN_GRASS), (7, -2, LEAF),
                         (-1, -5, SUN_GRASS), (-4, 7, SHADOW_GREEN), (4, 7, SHADOW_GREEN)):
        mid = (top[0] + dx // 2, top[1] + min(dy, 0) - 1)
        c.line([top, mid, (top[0] + dx, top[1] + dy)], fill, width=2 if abs(dx) > 4 else 1)
    c.dot(top, DARK_TIMBER)


def awning(c: Canvas, u0: float, u1: float, v: float, z: float, depth: float = 0.25) -> None:
    """A striped cloth awning sloping out from the lit wall."""
    n = 6
    for i in range(n):
        a, b = u0 + (u1 - u0) * i / n, u0 + (u1 - u0) * (i + 1) / n
        fill = CREAM if i % 2 == 0 else SUN_TERRACOTTA
        c.poly([c.p(a, v, z), c.p(b, v, z), c.p(b, v + depth, z - 3), c.p(a, v + depth, z - 3)], fill)
    c.line([c.p(u0, v + depth, z - 3), c.p(u1, v + depth, z - 3)], OUTLINE)
    c.line([c.p(u1, v, z), c.p(u1, v + depth, z - 3)], OUTLINE)


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
    overhang: float = 0.12
    lift: float = 0
    posts: Rgb | None = None


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
    if b.posts is not None:
        posts(c, b.u0, b.v0, b.u1, b.v1, 0, b.z, b.posts)
    if stage == "walls":
        flat_top(c, b.u0, b.v0, b.u1, b.v1, b.z, DARK_TIMBER)
        scaffold(c, b.u0, b.v0, b.u1, b.v1, b.z)
        return
    if b.roof_kind == "hip":
        hip_roof(c, b.u0, b.v0, b.u1, b.v1, b.z, b.rise, b.roof, overhang=b.overhang)
    elif b.roof_kind == "flat":
        flat_top(c, b.u0, b.v0, b.u1, b.v1, b.z, SHADOW_STONE)
    elif b.roof_kind == "flared":
        flared_roof(c, b.u0, b.v0, b.u1, b.v1, b.z, b.rise, b.roof, overhang=b.overhang, lift=b.lift)
    elif b.roof_kind == "parapet":
        parapet(c, b.u0, b.v0, b.u1, b.v1, b.z, b.wall)
    else:
        gable_roof(c, b.u0, b.v0, b.u1, b.v1, b.z, b.rise, b.roof, b.wall, axis=b.roof_kind[-1],
                   overhang=b.overhang)


# ---------------- culture styles ----------------

WHITEWASH = Material(CREAM, PALE_SAND)
PAPER_PLASTER = Material(PALE_SAND, LIGHT_STONE)
SANDSTONE = Material(SAND, LIGHT_LOAM)
DARK_TILE_ROOF = Material(SHADOW_STONE, SLATE)
WAINSCOT = Material(SHADOW_STONE, SLATE)
TILE_DOME = Material(HIGHLIGHT_WATER, MID_WATER)
WHITE_DOME = Material(CREAM, PALE_SAND)


@dataclass(frozen=True)
class Style:
    """How one culture builds: materials, roof shape and the small
    details (openings, posts, accent colour) that carry its look."""
    culture: str
    wall: Material
    base: Material  # ground floor of upgraded houses, towers, plinths
    roof: Material
    high_roof: Material  # merchants' houses, warehouse, library
    roof_kind: str  # gable_u | hip | flared | parapet
    rise: float  # multiplier on each building's base roof rise
    overhang: float
    lift: float  # eave upturn at the corners, px
    framed: bool  # half-timber framing on the lit wall
    posts: Rgb | None  # exposed post-and-beam frame
    accent: Rgb  # shutters, doors, tile trim
    openings: str  # mullion | shutter | lattice | arch
    dome: Material | None = None


NORTHERN_EUROPEAN = Style("northern-european", PLASTER, STONE_WALL, TILE_ROOF, SLATE_ROOF, "gable_u",
                          1.0, 0.12, 0, True, None, FLAG_RED, "mullion")
MEDITERRANEAN = Style("mediterranean", WHITEWASH, STONE_WALL, TILE_ROOF, TILE_ROOF, "hip",
                      0.45, 0.08, 0, False, None, MID_WATER, "shutter")
EAST_ASIAN = Style("east-asian", PAPER_PLASTER, WAINSCOT, SLATE_ROOF, SLATE_ROOF, "flared",
                   0.9, 0.2, 4, False, DARK_TIMBER, SUN_TERRACOTTA, "lattice")
MIDDLE_EASTERN = Style("middle-eastern", SANDSTONE, SANDSTONE, SANDSTONE, SANDSTONE, "parapet",
                       0.0, 0.0, 0, False, None, MID_WATER, "arch", dome=TILE_DOME)

STYLES: dict[str, Style] = {s.culture: s for s in (NORTHERN_EUROPEAN, MEDITERRANEAN, EAST_ASIAN, MIDDLE_EASTERN)}
# Cultures drawn with their own variants; Northern European is the base look.
CULTURES = ("mediterranean", "east-asian", "middle-eastern")
# Building kinds with a culture variant (plus the upgraded house tiers).
CULTURE_KINDS = ("house", "warehouse", "town-center", "library")


def _is_base(style: Style) -> bool:
    return style.culture == NORTHERN_EUROPEAN.culture


def _px(c: Canvas, u: float, v: float, z: float) -> tuple[int, int]:
    x, y = c.p(u, v, z)
    return round(x), round(y)


def style_window(c: Canvas, style: Style, u: float, v: float, z: float, lit: bool = True) -> None:
    if style.openings == "mullion":
        window(c, "left" if lit else "right", u, v, z, lit=lit)
        return
    x, y = _px(c, u, v, z)
    if style.openings == "shutter":
        arch(c, x, y + 1, 3, 4, DARK_TIMBER)
        shutter = style.accent if lit else DEEP_WATER
        c.draw.line([(x - 2, y - 2), (x - 2, y + 1)], fill=(*shutter, 255))
        c.draw.line([(x + 2, y - 2), (x + 2, y + 1)], fill=(*shutter, 255))
    elif style.openings == "lattice":
        c.draw.rectangle([x - 2, y - 2, x + 2, y + 1], fill=(*DARK_TIMBER, 255))
        pane = CREAM if lit else PALE_SAND
        for dx in (-1, 1):
            for dy in (-1, 0):
                c.dot((x + dx, y + dy), pane)
    else:
        arch(c, x, y + 1, 3, 3, DARK_TIMBER)


def style_door(c: Canvas, style: Style, u: float, v: float, height: int = 6, z0: float = 0) -> None:
    if style.openings == "mullion":
        door(c, u, v, z0, height=height)
        return
    x, y = _px(c, u, v, z0)
    if style.openings == "shutter":
        arch(c, x, y - 1, 3, height - 1, style.accent)
        c.draw.line([(x + 1, y - height + 2), (x + 1, y - 1)], fill=(*DEEP_WATER, 255))
    elif style.openings == "lattice":
        c.draw.rectangle([x - 2, y - height, x + 2, y - 1], fill=(*DARK_TIMBER, 255))
        for dx in (-1, 1):
            c.draw.line([(x + dx, y - height + 1), (x + dx, y - 3)], fill=(*PALE_SAND, 255))
    else:
        arch(c, x, y - 1, 5, height, style.accent)
        arch(c, x, y - 1, 3, height - 1, DARK_TIMBER)


def _cornice(c: Canvas, u0: float, v0: float, u1: float, v1: float, z: float, fill: Rgb) -> None:
    c.line([c.p(u0, v1, z), c.p(u1, v1, z), c.p(u1, v0, z)], fill)


# Mediterranean ----------------------------------------------------

def _house_mediterranean(c: Canvas, s: Style) -> None:
    b = Block(0.25, 0.45, 1.7, 1.6, 2 * STOREY, s.wall, s.roof, s.roof_kind, 14 * s.rise, overhang=s.overhang)
    draw_block(c, b, "done")
    style_door(c, s, 0.75, 1.6, height=7)
    style_window(c, s, 1.25, 1.6, 15)
    style_window(c, s, 0.45, 1.6, 15)
    style_window(c, s, 1.7, 1.0, 14, lit=False)
    box(c, 1.25, 0.6, 1.41, 0.76, 31, s.wall, z0=20)
    flat_top(c, 1.25, 0.6, 1.41, 0.76, 31, TERRACOTTA)
    amphora(c, 1.75, 1.85)
    amphora(c, 1.9, 1.7)


def _house_tier2_mediterranean(c: Canvas, s: Style) -> None:
    u0, v0, u1, v1 = 0.2, 0.2, 1.7, 1.7
    shadow(c, u0, v0, u1, v1)
    box(c, u0, v0, u1, v1, 26, s.wall)
    _cornice(c, u0, v0, u1, v1, 13, LIGHT_STONE)
    # Arcaded loggia along the ground floor.
    for u in (0.45, 0.85, 1.25):
        x, y = _px(c, u, v1, 0)
        arch(c, x, y - 1, 5, 8, DARK_TIMBER)
    style_door(c, s, 1.5, v1, height=8)
    for u in (0.45, 0.95, 1.45):
        style_window(c, s, u, v1, 21)
    style_window(c, s, u1, 0.7, 20, lit=False)
    style_window(c, s, u1, 1.25, 20, lit=False)
    style_window(c, s, u1, 0.95, 7, lit=False)
    hip_roof(c, u0, v0, u1, v1, 26, 7, s.roof, overhang=s.overhang)
    box(c, 1.25, 0.45, 1.41, 0.61, 41, s.wall, z0=26)
    flat_top(c, 1.25, 0.45, 1.41, 0.61, 41, TERRACOTTA)
    amphora(c, 1.85, 1.85)


def _house_tier3_mediterranean(c: Canvas, s: Style) -> None:
    # Belvedere tower on the back corner, its open loggia above the roofs.
    t0, t1 = 0.2, 0.75
    box(c, t0, t0, t1, t1, 60, s.wall)
    for k in (0.33, 0.6):
        x, y = _px(c, t0 + (t1 - t0) * k, t1, 50)
        arch(c, x, y, 3, 7, DARK_TIMBER)
        x, y = _px(c, t1, t0 + (t1 - t0) * k, 50)
        arch(c, x, y, 3, 7, OUTLINE)
    _cornice(c, t0, t0, t1, t1, 47, LIGHT_STONE)
    hip_roof(c, t0, t0, t1, t1, 60, 7, s.roof, overhang=0.06)
    u0, v0, u1, v1 = 0.15, 0.15, 1.75, 1.75
    shadow(c, u0, v0, u1, v1, 0.4)
    box(c, u0, v0, u1, v1, 14, s.base)
    box(c, u0, v0, u1, v1, 38, s.wall, z0=14)
    _cornice(c, u0, v0, u1, v1, 26, LIGHT_STONE)
    for u in (0.55, 0.95):
        x, y = _px(c, u, v1, 0)
        arch(c, x, y - 1, 5, 10, DARK_TIMBER)
    style_door(c, s, 1.4, v1, height=9)
    for z in (21, 33):
        for u in (0.4, 0.9, 1.4):
            style_window(c, s, u, v1, z)
        style_window(c, s, u1, 0.6, z - 1, lit=False)
        style_window(c, s, u1, 1.2, z - 1, lit=False)
    # Balcony slab with a dark railing over the door.
    c.poly([c.p(0.7, v1, 26), c.p(1.2, v1, 26), c.p(1.2, v1 + 0.1, 26), c.p(0.7, v1 + 0.1, 26)], LIGHT_STONE)
    c.line([c.p(0.7, v1 + 0.1, 28), c.p(1.2, v1 + 0.1, 28)], DARK_TIMBER)
    c.line([c.p(0.7, v1 + 0.1, 26), c.p(1.2, v1 + 0.1, 26)], OUTLINE)
    hip_roof(c, u0, v0, u1, v1, 38, 7, s.roof, overhang=s.overhang)


def _warehouse_mediterranean(c: Canvas, s: Style) -> None:
    b = Block(0.35, 0.35, 2.4, 2.25, 22, s.wall, s.roof, "hip", 18 * s.rise, overhang=s.overhang)
    draw_block(c, b, "done")
    _cornice(c, b.u0, b.v0, b.u1, b.v1, 3, LIGHT_STONE)
    for u in (0.95, 1.75):
        x, y = _px(c, u, b.v1, 0)
        arch(c, x, y - 1, 7, 13, DARK_TIMBER)
    for u in (0.6, 1.35, 2.1):
        style_window(c, s, u, b.v1, 19)
    style_window(c, s, b.u1, 1.25, 17, lit=False)
    style_window(c, s, b.u1, 0.75, 17, lit=False)
    for u, v in ((2.55, 2.45), (2.75, 2.35), (2.65, 2.7), (0.55, 2.55), (0.75, 2.7)):
        amphora(c, u, v)
    crate(c, 2.5, 2.8)


def _town_center_mediterranean(c: Canvas, s: Style) -> None:
    # Campanile on the back corner: tall square tower, open belfry, low
    # pyramid roof.
    t = (1.95, 0.3, 2.6, 0.95)
    shadow(c, *t)
    box(c, *t, 64, s.base)
    box(c, *t, 64, s.wall, z0=10)
    _cornice(c, *t, 10, LIGHT_STONE)
    _cornice(c, *t, 48, LIGHT_STONE)
    for k in (0.32, 0.68):
        x, y = _px(c, t[0] + (t[2] - t[0]) * k, t[3], 52)
        arch(c, x, y + 1, 3, 9, OUTLINE)
        c.dot((x, y - 6), WHEAT)
        x, y = _px(c, t[2], t[1] + (t[3] - t[1]) * k, 52)
        arch(c, x, y + 1, 3, 9, OUTLINE)
    style_window(c, s, t[2], 0.62, 34, lit=False)
    style_window(c, s, 2.27, t[3], 34)
    hip_roof(c, *t, 64, 10, s.roof, overhang=0.07)
    hall = Block(0.3, 0.6, 2.2, 2.6, 22, s.wall, s.roof, "hip", 16 * s.rise, overhang=s.overhang)
    draw_block(c, hall, "done")
    _cornice(c, hall.u0, hall.v0, hall.u1, hall.v1, 3, LIGHT_STONE)
    style_door(c, s, 1.2, 2.6, height=11)
    for u in (0.6, 1.8):
        x, y = _px(c, u, 2.6, 6)
        arch(c, x, y, 3, 9, DARK_TIMBER)
        c.draw.line([(x - 2, y - 8), (x - 2, y)], fill=(*s.accent, 255))
        c.draw.line([(x + 2, y - 8), (x + 2, y)], fill=(*s.accent, 255))
    style_window(c, s, 2.2, 1.6, 14, lit=False)
    style_window(c, s, 2.2, 1.0, 14, lit=False)


def _library_mediterranean(c: Canvas, s: Style) -> None:
    b = Block(0.2, 0.3, 1.75, 1.6, 24, s.wall, s.roof, "gable_u", 10, overhang=s.overhang)
    draw_block(c, b, "done")
    _cornice(c, b.u0, b.v0, b.u1, b.v1, 3, LIGHT_STONE)
    style_door(c, s, 0.5, 1.6, height=11)
    for u in (0.9, 1.25, 1.6):
        x, y = _px(c, u, 1.6, 7)
        arch(c, x, y, 3, 11, DARK_TIMBER)
    x, y = _px(c, 1.75, 0.95, 26)
    c.draw.ellipse([x - 2, y - 2, x + 2, y + 2], fill=(*DARK_TIMBER, 255))
    # Bell gable (espadaña) over the east gable end.
    box(c, 1.7, 0.75, 1.8, 1.15, 46, s.wall, z0=28)
    x, y = _px(c, 1.8, 0.95, 38)
    arch(c, x, y, 3, 6, OUTLINE)
    c.dot((x, y - 4), WHEAT)
    c.dot((x, y - 3), WHEAT)
    c.poly([c.p(1.7, 1.15, 46), c.p(1.8, 1.15, 46), c.p(1.8, 0.95, 50), c.p(1.7, 0.95, 50)], s.wall.lit)
    c.poly([c.p(1.8, 1.15, 46), c.p(1.8, 0.75, 46), c.p(1.8, 0.95, 50)], s.wall.shade)
    c.line([c.p(1.8, 1.15, 46), c.p(1.8, 0.95, 50), c.p(1.8, 0.75, 46)], OUTLINE)


# East Asian -------------------------------------------------------

def _storey(c: Canvas, s: Style, u0: float, v0: float, u1: float, v1: float, z0: float, z1: float,
            post: Rgb | None = None) -> None:
    box(c, u0, v0, u1, v1, z1, s.wall, z0=z0)
    posts(c, u0, v0, u1, v1, z0, z1, post or s.posts or DARK_TIMBER)


def _wainscot(c: Canvas, u0: float, v0: float, u1: float, v1: float, z: float) -> None:
    """Dark tiled plinth wall with a pale diagonal grid (namako)."""
    box(c, u0, v0, u1, v1, z, WAINSCOT)
    x0, y0 = c.p(u0, v1, 0)
    x1, _ = c.p(u1, v1, 0)
    for x in range(round(x0) + 1, round(x1) - 1):
        yb = y0 + (x - x0) * 0.5
        for k in range(1, int(z) - 1):
            if (x + k) % 4 == 0:
                c.dot((x, yb - k), LIGHT_STONE)


def _skirt_top(z: float, rise: float, h: float, nxt: float, overhang: float) -> float:
    return z + rise * (h - nxt + overhang) / (h + overhang)


def _house_east_asian(c: Canvas, s: Style) -> None:
    u0, v0, u1, v1 = 0.25, 0.5, 1.7, 1.5
    shadow(c, u0, v0, u1, v1)
    box(c, u0, v0, u1, v1, 4, s.base)
    _storey(c, s, u0, v0, u1, v1, 4, 20)
    style_door(c, s, 0.7, v1, height=10, z0=4)
    style_window(c, s, 1.15, v1, 14)
    style_window(c, s, 1.45, v1, 14)
    style_window(c, s, u1, 1.0, 13, lit=False)
    flared_roof(c, u0, v0, u1, v1, 20, 10, s.roof, overhang=s.overhang, lift=s.lift)
    bale(c, 1.8, 1.8)
    bale(c, 1.65, 1.9)


def _house_tier2_east_asian(c: Canvas, s: Style) -> None:
    u0, v0, u1, v1 = 0.2, 0.3, 1.75, 1.65
    shadow(c, u0, v0, u1, v1)
    box(c, u0, v0, u1, v1, 4, s.base)
    _storey(c, s, u0, v0, u1, v1, 4, 18)
    style_door(c, s, 0.6, v1, height=10, z0=4)
    style_window(c, s, 1.05, v1, 12)
    style_window(c, s, 1.45, v1, 12)
    style_window(c, s, u1, 0.95, 11, lit=False)
    flared_roof(c, u0, v0, u1, v1, 18, 5, s.roof, overhang=0.12, lift=2)
    a0, b0, a1, b1 = 0.38, 0.48, 1.57, 1.47
    z = _skirt_top(18, 5, 0.675, 0.495, 0.12)
    _storey(c, s, a0, b0, a1, b1, z, z + 12)
    for u in (0.7, 1.05, 1.4):
        style_window(c, s, u, b1, z + 8)
    style_window(c, s, a1, 0.95, z + 7, lit=False)
    flared_roof(c, a0, b0, a1, b1, z + 12, 10, s.roof, overhang=s.overhang, lift=s.lift)
    bale(c, 1.85, 1.85)


def _house_tier3_east_asian(c: Canvas, s: Style) -> None:
    u0, v0, u1, v1 = 0.15, 0.2, 1.8, 1.75
    shadow(c, u0, v0, u1, v1, 0.4)
    _wainscot(c, u0, v0, u1, v1, 6)
    _storey(c, s, u0, v0, u1, v1, 6, 18)
    style_door(c, s, 0.55, v1, height=10, z0=1)
    style_door(c, s, 0.9, v1, height=10, z0=1)
    style_window(c, s, 1.4, v1, 13)
    style_window(c, s, u1, 0.6, 13, lit=False)
    style_window(c, s, u1, 1.2, 13, lit=False)
    flared_roof(c, u0, v0, u1, v1, 18, 5, s.roof, overhang=0.12, lift=2)
    a0, b0, a1, b1 = 0.3, 0.35, 1.65, 1.6
    z = _skirt_top(18, 5, 0.775, 0.625, 0.12)
    _storey(c, s, a0, b0, a1, b1, z, z + 11)
    for u in (0.6, 1.0, 1.4):
        style_window(c, s, u, b1, z + 7)
    style_window(c, s, a1, 0.7, z + 6, lit=False)
    style_window(c, s, a1, 1.25, z + 6, lit=False)
    flared_roof(c, a0, b0, a1, b1, z + 11, 5, s.roof, overhang=0.12, lift=2)
    a2, b2, a3, b3 = 0.45, 0.5, 1.5, 1.45
    z = _skirt_top(z + 11, 5, 0.625, 0.475, 0.12)
    _storey(c, s, a2, b2, a3, b3, z, z + 10, post=s.accent)
    for u in (0.75, 1.2):
        style_window(c, s, u, b3, z + 7)
    flared_roof(c, a2, b2, a3, b3, z + 10, 10, s.roof, overhang=s.overhang, lift=s.lift)


def _warehouse_east_asian(c: Canvas, s: Style) -> None:
    u0, v0, u1, v1 = 0.3, 0.6, 2.6, 2.2
    shadow(c, u0, v0, u1, v1)
    _wainscot(c, u0, v0, u1, v1, 8)
    box(c, u0, v0, u1, v1, 24, WHITEWASH, z0=8)
    posts(c, u0, v0, u1, v1, 8, 24, DARK_TIMBER, step=0.7)
    for u in (0.95, 1.75):
        x, y = _px(c, u, v1, 0)
        c.draw.rectangle([x - 4, y - 13, x + 4, y - 1], fill=(*WHITEWASH.shade, 255))
        c.draw.rectangle([x - 3, y - 12, x + 3, y - 1], fill=(*DARK_TIMBER, 255))
        c.draw.line([(x, y - 12), (x, y - 1)], fill=(*TIMBER, 255))
    for u in (0.6, 1.35, 2.1):
        x, y = _px(c, u, v1, 19)
        c.draw.rectangle([x - 1, y - 2, x + 1, y], fill=(*DARK_TIMBER, 255))
    x, y = _px(c, u1, 1.4, 18)
    c.draw.rectangle([x - 1, y - 2, x + 1, y], fill=(*DARK_TIMBER, 255))
    flared_roof(c, u0, v0, u1, v1, 24, 12, s.roof, overhang=s.overhang, lift=s.lift)
    for u, v in ((2.55, 2.45), (2.75, 2.35), (2.65, 2.7), (0.55, 2.55)):
        bale(c, u, v)
    crate(c, 0.75, 2.6)


def _town_center_east_asian(c: Canvas, s: Style) -> None:
    """A three-storey pagoda on a stone platform, red lacquered posts."""
    box(c, 0.4, 0.4, 2.6, 2.6, 4, STONE_WALL)
    flat_top(c, 0.4, 0.4, 2.6, 2.6, 4, LIGHT_STONE)
    shadow(c, 0.65, 0.65, 2.35, 2.35, 0.25)
    # The ground storey and its door go first; stacked_roofs draws the rest.
    stacked_roofs(c, 1.5, 1.5, [0.72, 0.54, 0.38], [15, 12, 11], [8, 7, 12], s.wall, s.roof, s.accent, z0=4,
                  overhang=0.22, lift=4)
    x, y = _px(c, 1.5, 2.22, 4)
    c.draw.rectangle([x - 3, y - 10, x + 3, y - 1], fill=(*DARK_TIMBER, 255))
    c.draw.line([(x, y - 10), (x, y - 1)], fill=(*SUN_TERRACOTTA, 255))
    # Stone lanterns at the platform's front corners.
    for u, v in ((0.55, 2.35), (2.35, 2.5)):
        box(c, u, v, u + 0.1, v + 0.1, 12, STONE_WALL, z0=4)
        flat_top(c, u - 0.03, v - 0.03, u + 0.13, v + 0.13, 12, LIGHT_STONE)
        x, y = _px(c, u + 0.05, v + 0.1, 9)
        c.dot((x, y), CREAM)


def _library_east_asian(c: Canvas, s: Style) -> None:
    """A long hall on a stone plinth under one big upturned roof."""
    box(c, 0.1, 0.3, 1.9, 1.75, 5, STONE_WALL)
    flat_top(c, 0.1, 0.3, 1.9, 1.75, 5, LIGHT_STONE)
    u0, v0, u1, v1 = 0.3, 0.55, 1.7, 1.5
    _storey(c, s, u0, v0, u1, v1, 5, 21, post=s.accent)
    style_door(c, s, 0.95, v1, height=11, z0=5)
    for u in (0.55, 1.3, 1.55):
        style_window(c, s, u, v1, 15)
    style_window(c, s, u1, 0.85, 14, lit=False)
    style_window(c, s, u1, 1.2, 14, lit=False)
    # Steps up to the plinth.
    box(c, 0.8, 1.75, 1.1, 1.88, 2, STONE_WALL)
    flat_top(c, 0.8, 1.75, 1.1, 1.88, 2, LIGHT_STONE)
    flared_roof(c, u0, v0, u1, v1, 21, 18, s.roof, overhang=0.3, lift=5)


# Middle Eastern ---------------------------------------------------

def _house_middle_eastern(c: Canvas, s: Style) -> None:
    b = Block(0.3, 0.3, 1.6, 1.6, 18, s.wall, s.roof, "parapet")
    draw_block(c, b, "done")
    style_door(c, s, 0.7, 1.6, height=8)
    style_window(c, s, 1.25, 1.6, 12)
    style_window(c, s, 1.6, 0.8, 12, lit=False)
    style_window(c, s, 1.6, 1.25, 12, lit=False)
    awning(c, 0.45, 0.95, 1.6, 11)
    sack(c, 1.75, 1.85)
    palm(c, 0.15, 1.85)


def _house_tier2_middle_eastern(c: Canvas, s: Style) -> None:
    u0, v0, u1, v1 = 0.2, 0.2, 1.7, 1.7
    shadow(c, u0, v0, u1, v1)
    box(c, u0, v0, u1, v1, 22, s.wall)
    style_door(c, s, 0.55, v1, height=9)
    style_window(c, s, 0.95, v1, 8)
    style_window(c, s, u1, 0.65, 16, lit=False)
    style_window(c, s, u1, 1.1, 16, lit=False)
    style_window(c, s, u1, 1.1, 7, lit=False)
    mashrabiya(c, 1.3, v1, 11, height=9)
    parapet(c, u0, v0, u1, v1, 22, s.wall)
    a, b = 0.28, 1.0
    box(c, a, a, b, b, 34, s.wall, z0=22)
    style_window(c, s, 0.65, b, 29)
    style_window(c, s, b, 0.6, 29, lit=False)
    parapet(c, a, a, b, b, 34, s.wall)
    sack(c, 1.85, 1.85)


def _house_tier3_middle_eastern(c: Canvas, s: Style) -> None:
    u0, v0, u1, v1 = 0.15, 0.15, 1.75, 1.75
    shadow(c, u0, v0, u1, v1, 0.4)
    box(c, u0, v0, u1, v1, 34, s.wall)
    _cornice(c, u0, v0, u1, v1, 12, PALE_SAND)
    _cornice(c, u0, v0, u1, v1, 23, PALE_SAND)
    style_door(c, s, 0.5, v1, height=9)
    style_window(c, s, 0.9, v1, 7)
    style_window(c, s, 1.45, v1, 7)
    mashrabiya(c, 0.75, v1, 14, height=8)
    mashrabiya(c, 1.35, v1, 25, height=7)
    style_window(c, s, 1.35, v1, 19)
    style_window(c, s, 0.5, v1, 30)
    for z in (8, 19, 30):
        style_window(c, s, u1, 0.6, z, lit=False)
        style_window(c, s, u1, 1.25, z, lit=False)
    parapet(c, u0, v0, u1, v1, 34, s.wall)
    # Wind tower (badgir) on the back corner, slotted near the top.
    a, b = 0.28, 0.66
    box(c, a, a, b, b, 60, s.wall, z0=34)
    for k in (0.25, 0.5, 0.75):
        t = a + (b - a) * k
        c.line([c.p(t, b, 51), c.p(t, b, 57)], DARK_TIMBER)
        c.line([c.p(b, t, 51), c.p(b, t, 57)], OUTLINE)
    _cornice(c, a, a, b, b, 49, PALE_SAND)
    parapet(c, a, a, b, b, 60, s.wall, height=2, rim=0.05)


def _warehouse_middle_eastern(c: Canvas, s: Style) -> None:
    b = Block(0.35, 0.35, 2.4, 2.25, 24, s.wall, s.roof, "parapet")
    shadow(c, b.u0, b.v0, b.u1, b.v1)
    box(c, b.u0, b.v0, b.u1, b.v1, b.z, b.wall)
    # Pointed-arch gateway framed in blue tile.
    x, y = _px(c, 1.2, b.v1, 0)
    arch(c, x, y - 1, 11, 18, s.accent)
    arch(c, x, y - 1, 7, 16, DARK_TIMBER)
    for u in (0.6, 1.8, 2.15):
        style_window(c, s, u, b.v1, 19)
    style_window(c, s, b.u1, 0.75, 18, lit=False)
    style_window(c, s, b.u1, 1.3, 18, lit=False)
    style_window(c, s, b.u1, 1.85, 18, lit=False)
    awning(c, 1.65, 2.3, b.v1, 12, depth=0.3)
    parapet(c, b.u0, b.v0, b.u1, b.v1, b.z, b.wall)
    for u, v in ((2.6, 2.45), (2.8, 2.35), (2.7, 2.7), (0.55, 2.55), (0.75, 2.7)):
        sack(c, u, v)
    crate(c, 2.45, 2.75)
    palm(c, 0.2, 2.8, 26)


def _town_center_middle_eastern(c: Canvas, s: Style) -> None:
    # Minaret on the back corner: shaft, balcony, upper shaft, small dome.
    m0, m1 = 2.2, 2.56
    shadow(c, m0, 0.3, m1, 0.66)
    box(c, m0, 0.3, m1, 0.66, 52, s.wall)
    box(c, m0 - 0.06, 0.24, m1 + 0.06, 0.72, 55, s.wall, z0=51)
    parapet(c, m0 - 0.06, 0.24, m1 + 0.06, 0.72, 55, s.wall, height=2, rim=0.05)
    box(c, m0 + 0.06, 0.36, m1 - 0.06, 0.6, 66, s.wall, z0=55)
    dome(c, 2.38, 0.48, 66, 7, 0, s.dome, s.wall, height=8)
    for z in (20, 36):
        style_window(c, s, m1, 0.48, z, lit=False)
    hall = Block(0.3, 0.6, 2.3, 2.6, 22, s.wall, s.roof, "parapet")
    shadow(c, hall.u0, hall.v0, hall.u1, hall.v1)
    box(c, hall.u0, hall.v0, hall.u1, hall.v1, hall.z, hall.wall)
    # Iwan: a tall arched portal framed in blue tile.
    x, y = _px(c, 1.3, hall.v1, 0)
    arch(c, x, y - 1, 13, 20, s.accent)
    arch(c, x, y - 1, 9, 18, DARK_TIMBER)
    c.draw.rectangle([x - 1, y - 8, x + 1, y - 1], fill=(*TIMBER, 255))
    for u in (0.6, 2.0):
        style_window(c, s, u, hall.v1, 14)
    for v in (1.0, 1.6, 2.2):
        style_window(c, s, hall.u1, v, 14, lit=False)
    parapet(c, hall.u0, hall.v0, hall.u1, hall.v1, hall.z, hall.wall)
    dome(c, 1.25, 1.55, 25, 22, 6, s.dome, s.wall, band=s.accent)


def _library_middle_eastern(c: Canvas, s: Style) -> None:
    b = Block(0.25, 0.35, 1.7, 1.6, 22, s.wall, s.roof, "parapet")
    shadow(c, b.u0, b.v0, b.u1, b.v1)
    box(c, b.u0, b.v0, b.u1, b.v1, b.z, b.wall)
    style_door(c, s, 0.55, b.v1, height=11)
    for u in (0.95, 1.25, 1.55):
        x, y = _px(c, u, b.v1, 7)
        arch(c, x, y, 5, 10, s.accent)
        arch(c, x, y - 1, 3, 9, DARK_TIMBER)
    style_window(c, s, b.u1, 0.8, 14, lit=False)
    style_window(c, s, b.u1, 1.2, 14, lit=False)
    parapet(c, b.u0, b.v0, b.u1, b.v1, b.z, b.wall)
    dome(c, 0.975, 0.975, 25, 15, 5, WHITE_DOME, s.wall, band=s.accent)


_CULTURE_DRAWERS: dict[str, dict[str, Callable[[Canvas, Style], None]]] = {
    "house": {"mediterranean": _house_mediterranean, "east-asian": _house_east_asian,
              "middle-eastern": _house_middle_eastern},
    "house-tier2": {"mediterranean": _house_tier2_mediterranean, "east-asian": _house_tier2_east_asian,
                    "middle-eastern": _house_tier2_middle_eastern},
    "house-tier3": {"mediterranean": _house_tier3_mediterranean, "east-asian": _house_tier3_east_asian,
                    "middle-eastern": _house_tier3_middle_eastern},
    "warehouse": {"mediterranean": _warehouse_mediterranean, "east-asian": _warehouse_east_asian,
                  "middle-eastern": _warehouse_middle_eastern},
    "town-center": {"mediterranean": _town_center_mediterranean, "east-asian": _town_center_east_asian,
                    "middle-eastern": _town_center_middle_eastern},
    "library": {"mediterranean": _library_mediterranean, "east-asian": _library_east_asian,
                "middle-eastern": _library_middle_eastern},
}


def _culture_variant(kind: str, style: Style, w: int, h: int) -> Image.Image:
    """A culture's finished look of `kind`: same footprint and anchor
    as the base sprite, generous canvas (the caller trims it)."""
    c = Canvas(w, h, 140)
    yard(c)
    _CULTURE_DRAWERS[kind][style.culture](c, style)
    return c.img


def _house(stage: str, style: Style = NORTHERN_EUROPEAN) -> Image.Image:
    if not _is_base(style):
        return _culture_variant("house", style, 2, 2)
    c = Canvas(2, 2, 56)
    yard(c)
    b = Block(0.3, 0.3, 1.6, 1.6, 2 * STOREY, style.wall, style.roof, style.roof_kind, 14, framed=style.framed)
    draw_block(c, b, stage)
    if stage in ("walls", "done"):
        door(c, 0.75, 1.6)
        window(c, "left", 1.2, 1.6, 15)
        window(c, "left", 0.5, 1.6, 15)
        window(c, "right", 1.6, 0.9, 13, lit=False)
    if stage == "done":
        chimney(c, 1.2, 0.55, 20, 38)
    return c.img


def _house_tier2(style: Style = NORTHERN_EUROPEAN) -> Image.Image:
    """Citizens: stone ground floor, half-timbered upper storey."""
    if not _is_base(style):
        return _culture_variant("house-tier2", style, 2, 2)
    c = Canvas(2, 2, 72)
    yard(c)
    shadow(c, 0.25, 0.25, 1.65, 1.65)
    box(c, 0.25, 0.25, 1.65, 1.65, 12, style.base)
    box(c, 0.2, 0.2, 1.7, 1.7, 26, style.wall, z0=12)
    timber_frame(c, 0.2, 1.7, 1.7, 12, 26, step=0.35)
    gable_roof(c, 0.2, 0.2, 1.7, 1.7, 26, 16, style.roof, style.wall, axis="u")
    door(c, 0.7, 1.65, height=7)
    for u in (0.45, 1.0, 1.45):
        window(c, "left", u, 1.7, 21)
    window(c, "left", 1.25, 1.65, 7)
    window(c, "right", 1.7, 0.8, 20, lit=False)
    chimney(c, 1.2, 0.5, 26, 46)
    crate(c, 1.75, 1.75)
    return c.img


def _house_tier3(style: Style = NORTHERN_EUROPEAN) -> Image.Image:
    """Merchants: three storeys of stone and timber under a slate hip
    roof, with two chimneys."""
    if not _is_base(style):
        return _culture_variant("house-tier3", style, 2, 2)
    c = Canvas(2, 2, 92)
    yard(c)
    shadow(c, 0.15, 0.15, 1.75, 1.75, 0.4)
    box(c, 0.15, 0.15, 1.75, 1.75, 14, style.base)
    box(c, 0.15, 0.15, 1.75, 1.75, 38, style.wall, z0=14)
    timber_frame(c, 0.15, 1.75, 1.75, 14, 26, step=0.32)
    timber_frame(c, 0.15, 1.75, 1.75, 26, 38, step=0.32)
    hip_roof(c, 0.15, 0.15, 1.75, 1.75, 38, 18, style.high_roof)
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


def _library(stage: str, style: Style = NORTHERN_EUROPEAN) -> Image.Image:
    """Stone hall with tall arched windows under a slate roof and a
    small bell turret."""
    if not _is_base(style):
        return _culture_variant("library", style, 2, 2)
    c = Canvas(2, 2, 70)
    yard(c)
    b = Block(0.2, 0.3, 1.75, 1.6, 24, style.base, style.high_roof, style.roof_kind, 16)
    draw_block(c, b, stage)
    if stage in ("walls", "done"):
        door(c, 0.5, 1.6, height=10)
        for u in (0.9, 1.25, 1.6):
            x, y = c.p(u, 1.6, 8)
            c.draw.rectangle([round(x) - 1, round(y) - 11, round(x) + 1, round(y)], fill=(*DARK_TIMBER, 255))
            c.draw.point((round(x), round(y) - 12), fill=(*DARK_TIMBER, 255))
        window(c, "right", 1.75, 0.9, 16, lit=False)
    if stage == "done":
        box(c, 0.85, 0.8, 1.15, 1.1, 50, style.base, z0=30)
        hip_roof(c, 0.85, 0.8, 1.15, 1.1, 50, 10, style.high_roof, overhang=0.05)
    return c.img


def _warehouse(stage: str, style: Style = NORTHERN_EUROPEAN) -> Image.Image:
    if not _is_base(style):
        return _culture_variant("warehouse", style, 3, 3)
    c = Canvas(3, 3, 60)
    yard(c)
    b = Block(0.35, 0.35, 2.4, 2.25, 24, style.base, style.high_roof, "hip", 18)
    draw_block(c, b, stage)
    if stage in ("walls", "done"):
        # Half-timbered upper storey over the stone ground floor.
        box(c, b.u0, b.v0, b.u1, b.v1, b.z, style.wall, z0=12)
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


def _town_center(stage: str, style: Style = NORTHERN_EUROPEAN) -> Image.Image:
    if not _is_base(style):
        return _culture_variant("town-center", style, 3, 3)
    c = Canvas(3, 3, 88)
    yard(c)
    hall = Block(0.3, 0.6, 2.2, 2.6, 22, style.base, style.roof, "hip", 16)
    tower = Block(1.85, 0.3, 2.7, 1.15, 46, style.base, style.high_roof, "flat")
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

_DRAWERS: dict[str, Callable[..., Image.Image]] = {
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
TIER_HOUSES: dict[int, Callable[..., Image.Image]] = {2: _house_tier2, 3: _house_tier3}


def draw_windmill_frame(frame: int, frames: int) -> Image.Image:
    """Operational windmill frame: the sails turn a quarter turn per cycle."""
    img = _windmill("done", math.pi / 4 + frame * (math.pi / 2) / frames)
    top = _windmill("done").getbbox()[1]
    return img.crop((0, max(0, top - HEADROOM), img.width, img.height))


def _trim(img: Image.Image) -> Image.Image:
    return img.crop((0, max(0, img.getbbox()[1] - HEADROOM), img.width, img.height))


def draw_house_tier(tier: int, culture: str | None = None) -> Image.Image:
    if culture is None:
        return _trim(TIER_HOUSES[tier]())
    return _trim(TIER_HOUSES[tier](STYLES[culture]))


# Room kept above the tallest pixel for the derived smoke plume.
HEADROOM = 14


def draw(kind: str, stage: str = "done", culture: str | None = None) -> Image.Image:
    """The building at `stage`, with empty canvas above the finished
    building's top trimmed off (the bottom anchor is unchanged).
    `culture` picks a culture's finished look; construction stages are
    shared, so it only applies to `done`."""
    if culture is not None:
        if stage != "done":
            raise ValueError("culture variants have no construction stages")
        return _trim(_DRAWERS[kind]("done", STYLES[culture]))
    img = _DRAWERS[kind](stage)
    top = _DRAWERS[kind]("done").getbbox()[1]
    return img.crop((0, max(0, top - HEADROOM), img.width, img.height))
