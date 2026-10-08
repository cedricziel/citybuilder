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
    CREAM, DARK_LOAM, DARK_TIMBER, DEEP_WATER, FLAG_RED, GLINT, HIGHLIGHT_WATER, LEAF, LIGHT_LOAM, LIGHT_STONE,
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


def stone_lantern(c: Canvas, u: float, v: float, z0: float = 0, height: float = 8, cap: float = 0.03) -> None:
    """A stone lantern: a square post under a wider cap, its light lit."""
    top = z0 + height
    box(c, u, v, u + 0.1, v + 0.1, top, STONE_WALL, z0=z0)
    flat_top(c, u - cap, v - cap, u + 0.1 + cap, v + 0.1 + cap, top, LIGHT_STONE)
    c.dot(_px(c, u + 0.05, v + 0.1, top - 3), CREAM)


def barrel(c: Canvas, u: float, v: float, z: float = 0) -> None:
    """A cask on its side, end towards the viewer, with an iron hoop."""
    x, y = _px(c, u, v, z)
    c.draw.ellipse([x - 4, y - 7, x + 4, y], fill=(*TIMBER, 255), outline=(*OUTLINE, 255))
    c.draw.ellipse([x - 2, y - 5, x + 2, y - 2], fill=(*PINE, 255), outline=(*DARK_TIMBER, 255))
    c.dot((x, y - 4), DARK_TIMBER)


def cypress(c: Canvas, u: float, v: float, height: int = 28) -> None:
    """A tall, narrow Mediterranean cypress."""
    x, y = _px(c, u, v, 0)
    c.draw.ellipse([x - 4, y - height, x + 4, y], fill=(*SHADOW_GREEN, 255), outline=(*OUTLINE, 255))
    c.draw.ellipse([x - 3, y - height + 2, x, y - 3], fill=(*LEAF, 255))
    c.line([(x, y), (x, y - 2)], DARK_TIMBER)


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


def _style_block(s: Style, u0: float, v0: float, u1: float, v1: float, z: float, rise: float) -> Block:
    return Block(u0, v0, u1, v1, z, s.wall, s.roof, s.roof_kind, rise * s.rise, framed=s.framed,
                 overhang=s.overhang, lift=s.lift, posts=s.posts)


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
        stone_lantern(c, u, v, z0=4)


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


# ---------------- ages ----------------
#
# House looks per historical age (design `add-historical-ages` D7). The
# medieval look is the culture styles above; every other age composes
# `age_style(culture, age)`: the culture's identity (roof shape, signature
# details, accent) with the age's materials and shapes.

AGES = ("antiquity", "renaissance", "industrial", "modern")

BRICK = Material(SUN_TERRACOTTA, TERRACOTTA)
MUD_BRICK = Material(LIGHT_LOAM, MEDIUM_LOAM)
TRAVERTINE = Material(PALE_SAND, LIGHT_STONE)
OCHRE_STUCCO = Material(WHEAT, PINE)
CONCRETE = Material(CREAM, LIGHT_STONE)
CLADDING = Material(PINE, TIMBER)
DARK_PANEL = Material(SHADOW_STONE, SLATE)
GLASS = Material(HIGHLIGHT_WATER, MID_WATER)


@dataclass(frozen=True)
class AgeStyle:
    """A culture's style as built in one age."""
    age: str
    culture: Style
    wall: Material
    base: Material  # plinth, ground floor, cladding or dado
    roof: Material
    roof_kind: str  # hip | gable_u | gable_v | flared | parapet | flat
    trim: Rgb  # cornices, lintels, window surrounds

    @property
    def name(self) -> str:
        return self.culture.culture


# (wall, base, roof, roof kind, trim) per age and culture.
_AGE_LOOKS: dict[str, dict[str, tuple[Material, Material, Material, str, Rgb]]] = {
    "antiquity": {
        "northern-european": (STONE_WALL, STONE_WALL, THATCH_ROOF, "hip", LIGHT_STONE),
        "mediterranean": (TRAVERTINE, BRICK, TILE_ROOF, "hip", CREAM),
        "east-asian": (MUD_BRICK, STONE_WALL, THATCH_ROOF, "flared", TIMBER),
        "middle-eastern": (MUD_BRICK, MUD_BRICK, MUD_BRICK, "parapet", SAND),
    },
    "renaissance": {
        "northern-european": (WHITEWASH, STONE_WALL, TILE_ROOF, "gable_v", LIGHT_STONE),
        "mediterranean": (OCHRE_STUCCO, STONE_WALL, TILE_ROOF, "hip", CREAM),
        "east-asian": (WHITEWASH, DARK_PANEL, DARK_TILE_ROOF, "gable_u", DARK_TIMBER),
        "middle-eastern": (TRAVERTINE, STONE_WALL, TRAVERTINE, "parapet", CREAM),
    },
    "industrial": {
        "northern-european": (BRICK, STONE_WALL, SLATE_ROOF, "gable_u", LIGHT_STONE),
        "mediterranean": (BRICK, STONE_WALL, SLATE_ROOF, "hip", LIGHT_STONE),
        "east-asian": (BRICK, STONE_WALL, SLATE_ROOF, "flared", LIGHT_STONE),
        "middle-eastern": (BRICK, STONE_WALL, BRICK, "parapet", PALE_SAND),
    },
    "modern": {
        "northern-european": (CONCRETE, CLADDING, CONCRETE, "flat", FLAG_RED),
        "mediterranean": (CONCRETE, CONCRETE, CONCRETE, "flat", MID_WATER),
        "east-asian": (CONCRETE, DARK_PANEL, DARK_TILE_ROOF, "flat", SUN_TERRACOTTA),
        "middle-eastern": (CONCRETE, SANDSTONE, CONCRETE, "flat", MID_WATER),
    },
}


def age_style(culture: str, age: str) -> AgeStyle:
    wall, base, roof, kind, trim = _AGE_LOOKS[age][culture]
    return AgeStyle(age, STYLES[culture], wall, base, roof, kind, trim)


def _face(c: Canvas, face: str, a0: float, a1: float, at: float, z0: float, z1: float, fill: Rgb) -> None:
    """A rectangle on the lit (v = at, spanning u) or shaded (u = at,
    spanning v) wall plane."""
    if face == "lit":
        pts = [c.p(a0, at, z0), c.p(a1, at, z0), c.p(a1, at, z1), c.p(a0, at, z1)]
    else:
        pts = [c.p(at, a0, z0), c.p(at, a1, z0), c.p(at, a1, z1), c.p(at, a0, z1)]
    c.poly(pts, fill)


def _face_line(c: Canvas, face: str, a0: float, a1: float, at: float, z: float, fill: Rgb) -> None:
    if face == "lit":
        c.line([c.p(a0, at, z), c.p(a1, at, z)], fill)
    else:
        c.line([c.p(at, a0, z), c.p(at, a1, z)], fill)


def _brickwork(c: Canvas, u0: float, v0: float, u1: float, v1: float, z0: float, z1: float) -> None:
    """Broken brick courses on both visible walls, staggered per row."""
    row = 0
    z = z0 + 3
    while z < z1 - 1:
        for (a, b, fill) in ((c.p(u0, v1, z), c.p(u1, v1, z), TERRACOTTA), (c.p(u1, v1, z), c.p(u1, v0, z), SLATE)):
            xa, xb = round(a[0]) + 1, round(b[0]) - 1
            for x in range(xa, xb):
                if (x // 3 + row) % 2 == 0:
                    y = a[1] + (b[1] - a[1]) * (x - a[0]) / (b[0] - a[0])
                    c.dot((x, y), fill)
        row += 1
        z += 4


def _glass(c: Canvas, face: str, a0: float, a1: float, at: float, z0: float, z1: float) -> None:
    """A wide window band: blue glass with dark mullions and a glint."""
    _face(c, face, a0, a1, at, z0, z1, GLASS.lit if face == "lit" else GLASS.shade)
    n = max(1, round((a1 - a0) / 0.22))
    for i in range(1, n):
        a = a0 + (a1 - a0) * i / n
        if face == "lit":
            c.line([c.p(a, at, z0), c.p(a, at, z1)], DEEP_WATER)
        else:
            c.line([c.p(at, a, z0), c.p(at, a, z1)], DEEP_WATER)
    _face_line(c, face, a0, a1, at, z0, DEEP_WATER)
    if face == "lit":
        x, y = _px(c, a0 + 0.04, at, z1 - 1)
        c.dot((x + 1, y + 1), GLINT)


def _balcony(c: Canvas, face: str, a0: float, a1: float, at: float, z: float, depth: float = 0.14,
             rail: Rgb = CREAM, slab: Rgb = LIGHT_STONE) -> None:
    """A slab projecting from a wall with a railing along its edge."""
    if face == "lit":
        top = [c.p(a0, at, z), c.p(a1, at, z), c.p(a1, at + depth, z), c.p(a0, at + depth, z)]
        edge = (c.p(a0, at + depth, z), c.p(a1, at + depth, z))
        rail_pts = [c.p(a0, at + depth, z + 4), c.p(a1, at + depth, z + 4)]
        ends = [(a0, at + depth), (a1, at + depth)]
    else:
        top = [c.p(at, a0, z), c.p(at, a1, z), c.p(at + depth, a1, z), c.p(at + depth, a0, z)]
        edge = (c.p(at + depth, a0, z), c.p(at + depth, a1, z))
        rail_pts = [c.p(at + depth, a0, z + 4), c.p(at + depth, a1, z + 4)]
        ends = [(at + depth, a0), (at + depth, a1)]
    c.poly(top, slab)
    c.line([(edge[0][0], edge[0][1] + 1), (edge[1][0], edge[1][1] + 1)], OUTLINE)
    c.line(list(edge), slab)
    c.line(rail_pts, rail)
    for u, v in ends:
        c.line([c.p(u, v, z), c.p(u, v, z + 4)], rail)


def _columns(c: Canvas, u0: float, u1: float, v: float, z0: float, z1: float, n: int,
             lit: Rgb = CREAM, shade: Rgb = LIGHT_STONE) -> None:
    """A row of round columns, 2 px wide, outlined on their shaded side."""
    for i in range(n):
        u = u0 + (u1 - u0) * i / max(1, n - 1)
        x, y0 = _px(c, u, v, z0)
        _, y1 = _px(c, u, v, z1)
        c.draw.rectangle([x - 1, y1, x, y0], fill=(*lit, 255))
        c.draw.line([(x, y1), (x, y0)], fill=(*shade, 255))
        c.draw.line([(x + 1, y1 + 1), (x + 1, y0)], fill=(*OUTLINE, 255))


def _portico(c: Canvas, u0: float, u1: float, v: float, depth: float, z: float, n: int, roof: Material,
             pediment: Material, col: tuple[Rgb, Rgb] = (CREAM, LIGHT_STONE), recess: Rgb = SHADOW_STONE) -> None:
    """A columned porch in front of the lit wall under a gable whose
    pediment faces the viewer: a temple front."""
    _face(c, "lit", u0, u1, v, 0, z, recess)
    box(c, u0 - 0.04, v, u1 + 0.04, v + depth + 0.04, 2, STONE_WALL)
    flat_top(c, u0 - 0.04, v, u1 + 0.04, v + depth + 0.04, 2, LIGHT_STONE)
    _columns(c, u0 + 0.04, u1 - 0.04, v + depth, 2, z, n, *col)
    box(c, u0, v, u1, v + depth, z + 3, pediment, z0=z)
    gable_roof(c, u0, v - 0.05, u1, v + depth, z + 3, 9, roof, pediment, axis="v", overhang=0.05)


def _stepped_gable(c: Canvas, u0: float, u1: float, v: float, z: float, rise: float, mat: Material,
                   steps: int = 3) -> None:
    """A Flemish stepped gable on the lit wall, covering the end of a
    gable roof whose ridge runs along v."""
    w = (u1 - u0) / 2 / steps
    pts: list[Point] = [c.p(u0, v, z)]
    for i in range(steps):
        zt = z + rise * (i + 1) / steps
        pts += [c.p(u0 + w * i, v, zt), c.p(u0 + w * (i + 1), v, zt)]
    for i in reversed(range(steps)):
        zt = z + rise * (i + 1) / steps
        pts += [c.p(u1 - w * (i + 1), v, zt), c.p(u1 - w * i, v, zt)]
    pts.append(c.p(u1, v, z))
    c.poly(pts, mat.lit)
    c.line(pts[1:-1], OUTLINE)
    x, y = _px(c, (u0 + u1) / 2, v, z + rise * 0.5)
    c.draw.ellipse([x - 1, y - 1, x + 1, y + 1], fill=(*DARK_TIMBER, 255))


def _brick_chimney(c: Canvas, u: float, v: float, z0: float, z1: float) -> None:
    box(c, u, v, u + 0.16, v + 0.16, z1, BRICK, z0=z0)
    box(c, u - 0.02, v - 0.02, u + 0.18, v + 0.18, z1 + 2, STONE_WALL, z0=z1)
    flat_top(c, u - 0.02, v - 0.02, u + 0.18, v + 0.18, z1 + 2, OUTLINE)


def _age_window(c: Canvas, s: AgeStyle, u: float, v: float, z: float, lit: bool = True) -> None:
    """One window in the age's manner, dressed in the culture's openings."""
    x, y = _px(c, u, v, z)
    dark = DARK_TIMBER if lit else OUTLINE
    culture = s.culture
    if s.age == "antiquity":
        if culture.openings == "arch":
            arch(c, x, y + 1, 3, 3, OUTLINE)
        else:
            c.draw.rectangle([x - 1, y - 1, x, y + 1], fill=(*dark, 255))
        return
    if s.age == "renaissance":
        if culture.openings == "lattice":
            c.draw.rectangle([x - 2, y - 2, x + 2, y + 1], fill=(*DARK_TIMBER, 255))
            for dx in (-1, 0, 1):
                c.draw.line([(x + dx, y - 1), (x + dx, y)], fill=(*(PALE_SAND if dx else DARK_TIMBER), 255))
            return
        frame = s.trim if lit else s.wall.shade
        if culture.openings == "arch":
            arch(c, x, y + 2, 5, 6, frame)
            arch(c, x, y + 1, 3, 4, dark)
            return
        c.draw.rectangle([x - 2, y - 4, x + 2, y + 2], fill=(*frame, 255))
        c.draw.rectangle([x - 1, y - 3, x + 1, y + 1], fill=(*dark, 255))
        if culture.openings == "shutter":
            sh = culture.accent if lit else DEEP_WATER
            c.draw.line([(x - 2, y - 3), (x - 2, y + 1)], fill=(*sh, 255))
            c.draw.line([(x + 2, y - 3), (x + 2, y + 1)], fill=(*sh, 255))
        return
    if s.age == "industrial":
        c.draw.line([(x - 2, y - 4), (x + 2, y - 4)], fill=(*(s.trim if lit else STONE), 255))
        if culture.openings == "arch":
            arch(c, x, y + 1, 3, 4, dark)
        else:
            c.draw.rectangle([x - 1, y - 3, x + 1, y + 1], fill=(*dark, 255))
        c.dot((x, y - 1), CREAM if lit else LIGHT_STONE)
        return
    c.draw.rectangle([x - 2, y - 2, x + 2, y + 1], fill=(*(GLASS.lit if lit else GLASS.shade), 255))
    c.draw.line([(x, y - 2), (x, y + 1)], fill=(*DEEP_WATER, 255))


def _age_door(c: Canvas, s: AgeStyle, u: float, v: float, height: int = 7, z0: float = 0) -> None:
    x, y = _px(c, u, v, z0)
    culture = s.culture
    if s.age == "antiquity":
        if culture.openings == "arch":
            arch(c, x, y - 1, 3, height - 1, OUTLINE)
        else:
            c.draw.rectangle([x - 1, y - height, x + 1, y - 1], fill=(*OUTLINE, 255))
        return
    if s.age == "renaissance":
        if culture.openings == "lattice":
            style_door(c, culture, u, v, height=height, z0=z0)
            return
        arch(c, x, y - 1, 5, height + 1, s.trim)
        arch(c, x, y - 1, 3, height, culture.accent if culture.openings != "mullion" else DARK_TIMBER)
        return
    if s.age == "industrial":
        c.draw.rectangle([x - 2, y - height - 1, x + 2, y - 1], fill=(*s.trim, 255))
        c.draw.rectangle([x - 1, y - height + 1, x + 1, y - 1], fill=(*DARK_TIMBER, 255))
        c.draw.line([(x - 1, y - height), (x + 1, y - height)], fill=(*HIGHLIGHT_WATER, 255))
        return
    c.draw.rectangle([x - 2, y - height, x + 2, y - 1], fill=(*DEEP_WATER, 255))
    c.draw.rectangle([x - 1, y - height + 1, x + 1, y - 1], fill=(*GLASS.lit, 255))
    c.draw.line([(x - 3, y - height - 1), (x + 3, y - height - 1)], fill=(*s.trim, 255))


def _age_roof(c: Canvas, s: AgeStyle, u0: float, v0: float, u1: float, v1: float, z: float, rise: float,
              lift: float = 3) -> None:
    kind = s.roof_kind
    if kind == "hip":
        hip_roof(c, u0, v0, u1, v1, z, rise, s.roof, overhang=0.1)
    elif kind in ("gable_u", "gable_v"):
        gable_roof(c, u0, v0, u1, v1, z, rise, s.roof, s.wall, axis=kind[-1])
    elif kind == "flared":
        flared_roof(c, u0, v0, u1, v1, z, rise, s.roof, overhang=0.18, lift=lift)
    elif kind == "parapet":
        deck = SHADOW_STONE if s.age == "industrial" else s.wall.shade
        parapet(c, u0, v0, u1, v1, z, s.wall, cap=s.trim, deck=deck)
    else:
        parapet(c, u0, v0, u1, v1, z, s.wall, height=2, rim=0.05, cap=CREAM, deck=SHADOW_STONE)


def _vigas(c: Canvas, u0: float, v0: float, u1: float, v1: float, z: float) -> None:
    """Roof-beam ends poking through a mud-brick wall."""
    n = max(2, round((u1 - u0) / 0.2))
    for i in range(1, n):
        x, y = _px(c, u0 + (u1 - u0) * i / n, v1, z)
        c.dot((x, y), DARK_TIMBER)
        c.dot((x - 1, y), DARK_TIMBER)
    n = max(2, round((v1 - v0) / 0.2))
    for i in range(1, n):
        x, y = _px(c, u1, v0 + (v1 - v0) * i / n, z)
        c.dot((x, y), OUTLINE)
        c.dot((x + 1, y), OUTLINE)


def _pilasters(c: Canvas, s: AgeStyle, u0: float, u1: float, v: float, z0: float, z1: float, n: int) -> None:
    for i in range(n):
        u = u0 + (u1 - u0) * i / max(1, n - 1)
        x, y0 = _px(c, u, v, z0)
        _, y1 = _px(c, u, v, z1)
        c.draw.rectangle([x - 1, y1, x, y0], fill=(*s.trim, 255))


def _lean_logs(c: Canvas, u: float, v: float) -> None:
    log_pile(c, u, v, 2)


# Antiquity ------------------------------------------------------------

def _antiquity_1(c: Canvas, s: AgeStyle) -> None:
    n = s.name
    if n == "northern-european":
        # Stone-and-thatch longhouse: low walls under a deep roof.
        u0, v0, u1, v1 = 0.15, 0.55, 1.85, 1.45
        shadow(c, u0, v0, u1, v1)
        box(c, u0, v0, u1, v1, 12, s.wall)
        _age_door(c, s, 0.75, v1, height=7)
        _age_window(c, s, 1.3, v1, 7)
        _age_window(c, s, u1, 1.0, 7, lit=False)
        hip_roof(c, u0, v0, u1, v1, 12, 16, s.roof, overhang=0.1)
        x, y = _px(c, 1.25, 1.0, 26)
        c.draw.rectangle([x - 1, y - 1, x + 1, y], fill=(*DARK_LOAM, 255))
        _lean_logs(c, 0.25, 1.85)
    elif n == "mediterranean":
        u0, v0, u1, v1 = 0.3, 0.45, 1.65, 1.6
        shadow(c, u0, v0, u1, v1)
        box(c, u0, v0, u1, v1, 14, s.wall)
        box(c, u0, v0, u1, v1, 4, s.base)
        _age_door(c, s, 0.8, v1, height=8)
        _age_window(c, s, 1.3, v1, 10)
        _age_window(c, s, u1, 1.0, 10, lit=False)
        hip_roof(c, u0, v0, u1, v1, 14, 6, s.roof, overhang=0.08)
        amphora(c, 1.8, 1.85)
    elif n == "east-asian":
        u0, v0, u1, v1 = 0.3, 0.5, 1.65, 1.5
        shadow(c, u0, v0, u1, v1)
        box(c, u0, v0, u1, v1, 4, s.base)
        flat_top(c, u0, v0, u1, v1, 4, LIGHT_STONE)
        a0, b0, a1, b1 = u0 + 0.08, v0 + 0.08, u1 - 0.08, v1 - 0.08
        box(c, a0, b0, a1, b1, 17, s.wall, z0=4)
        posts(c, a0, b0, a1, b1, 4, 17, DARK_TIMBER, step=0.35)
        _age_door(c, s, 0.75, b1, height=9, z0=4)
        _age_window(c, s, 1.3, b1, 12)
        _age_window(c, s, a1, 1.0, 12, lit=False)
        flared_roof(c, a0, b0, a1, b1, 17, 14, s.roof, overhang=0.18, lift=4)
        bale(c, 1.8, 1.8)
    else:
        u0, v0, u1, v1 = 0.35, 0.35, 1.6, 1.6
        shadow(c, u0, v0, u1, v1)
        box(c, u0, v0, u1, v1, 14, s.wall)
        _vigas(c, u0, v0, u1, v1, 12)
        _age_door(c, s, 0.75, v1, height=7)
        _age_window(c, s, 1.3, v1, 9)
        _age_window(c, s, u1, 1.0, 9, lit=False)
        _age_roof(c, s, u0, v0, u1, v1, 14, 0)
        sack(c, 1.8, 1.85)
        palm(c, 0.15, 1.85, 18)


def _antiquity_2(c: Canvas, s: AgeStyle) -> None:
    n = s.name
    if n == "northern-european":
        # A longer longhouse with a timber byre lean-to.
        box(c, 1.35, 0.15, 1.85, 0.6, 6, TIMBER_WALL)
        gable_roof(c, 1.35, 0.15, 1.85, 0.6, 6, 7, s.roof, TIMBER_WALL, axis="v")
        u0, v0, u1, v1 = 0.1, 0.55, 1.9, 1.65
        shadow(c, u0, v0, u1, v1)
        box(c, u0, v0, u1, v1, 14, s.wall)
        _age_door(c, s, 0.6, v1, height=8)
        _age_door(c, s, 1.5, v1, height=8)
        _age_window(c, s, 1.05, v1, 9)
        _age_window(c, s, u1, 1.1, 9, lit=False)
        hip_roof(c, u0, v0, u1, v1, 14, 20, s.roof, overhang=0.1)
        for uu in (0.7, 1.3):
            x, y = _px(c, uu, 1.1, 31)
            c.draw.rectangle([x - 1, y - 1, x + 1, y], fill=(*DARK_LOAM, 255))
    elif n == "mediterranean":
        # Domus: a blank-walled block around an atrium open to the sky.
        u0, v0, u1, v1 = 0.2, 0.25, 1.75, 1.7
        shadow(c, u0, v0, u1, v1)
        box(c, u0, v0, u1, v1, 16, s.wall)
        box(c, u0, v0, u1, v1, 5, s.base)
        _age_door(c, s, 0.7, v1, height=9)
        for uu in (1.15, 1.45):
            _age_window(c, s, uu, v1, 12)
        _age_window(c, s, u1, 0.7, 12, lit=False)
        _age_window(c, s, u1, 1.2, 12, lit=False)
        hip_roof(c, u0, v0, u1, v1, 16, 7, s.roof, overhang=0.08)
        # Compluvium: the opening over the atrium pool.
        a0, b0, a1, b1 = 0.8, 0.8, 1.15, 1.15
        c.poly([c.p(a0, b0, 20), c.p(a1, b0, 20), c.p(a1, b1, 20), c.p(a0, b1, 20)], OUTLINE)
        c.poly([c.p(a0 + 0.06, b0 + 0.06, 18), c.p(a1, b0 + 0.06, 18), c.p(a1, b1, 18), c.p(a0 + 0.06, b1, 18)],
               MID_WATER)
        amphora(c, 1.85, 1.85)
    elif n == "east-asian":
        # Hall on a stone base beside a raised granary on stilts.
        u0, v0, u1, v1 = 0.15, 0.2, 1.4, 1.35
        shadow(c, u0, v0, u1, v1)
        box(c, u0, v0, u1, v1, 4, s.base)
        flat_top(c, u0, v0, u1, v1, 4, LIGHT_STONE)
        a0, b0, a1, b1 = u0 + 0.08, v0 + 0.08, u1 - 0.08, v1 - 0.08
        box(c, a0, b0, a1, b1, 19, s.wall, z0=4)
        posts(c, a0, b0, a1, b1, 4, 19, DARK_TIMBER, step=0.35)
        _age_door(c, s, 0.55, b1, height=9, z0=4)
        _age_window(c, s, 1.0, b1, 13)
        _age_window(c, s, a1, 0.75, 13, lit=False)
        flared_roof(c, a0, b0, a1, b1, 19, 16, s.roof, overhang=0.2, lift=4)
        g0, h0, g1, h1 = 1.4, 1.3, 1.85, 1.75
        for uu, vv in ((g0, h1), (g1, h1), (g1, h0)):
            c.line([c.p(uu, vv, 0), c.p(uu, vv, 9)], DARK_TIMBER)
            c.line([c.p(uu, vv, 0), c.p(uu, vv, 9)], DARK_TIMBER)
        box(c, g0, h0, g1, h1, 18, CLADDING, z0=9)
        c.line([c.p(g0 + 0.1, h1, 0), c.p(g0 + 0.25, h1, 9)], TIMBER)
        flared_roof(c, g0, h0, g1, h1, 18, 10, s.roof, overhang=0.1, lift=2)
    else:
        # Courtyard house: two flat-roofed wings and a walled yard.
        box(c, 0.2, 0.2, 1.8, 0.85, 22, s.wall)
        _vigas(c, 0.2, 0.2, 1.8, 0.85, 20)
        _age_window(c, s, 1.8, 0.5, 15, lit=False)
        _age_roof(c, s, 0.2, 0.2, 1.8, 0.85, 22, 0)
        u0, v0, u1, v1 = 0.2, 0.85, 0.95, 1.75
        shadow(c, u0, v0, u1, v1)
        box(c, u0, v0, u1, v1, 14, s.wall)
        _vigas(c, u0, v0, u1, v1, 12)
        _age_door(c, s, 0.55, v1, height=7)
        _age_window(c, s, u1, 1.3, 9, lit=False)
        _age_roof(c, s, u0, v0, u1, v1, 14, 0)
        # Courtyard wall with a gate, a palm inside.
        palm(c, 1.35, 1.25, 20)
        box(c, 0.95, 1.65, 1.8, 1.75, 7, s.wall)
        box(c, 1.7, 0.85, 1.8, 1.75, 7, s.wall)
        flat_top(c, 0.95, 1.65, 1.8, 1.75, 7, s.trim)
        flat_top(c, 1.7, 0.85, 1.8, 1.75, 7, s.trim)
        x, y = _px(c, 1.35, 1.75, 0)
        c.draw.rectangle([x - 1, y - 6, x + 1, y - 1], fill=(*OUTLINE, 255))


def _antiquity_3(c: Canvas, s: AgeStyle) -> None:
    n = s.name
    if n == "northern-european":
        # Chieftain's hall: high stone walls, a deep thatch roof and a
        # timber-posted porch with its own gable.
        u0, v0, u1, v1 = 0.12, 0.25, 1.88, 1.45
        shadow(c, u0, v0, u1, v1, 0.4)
        box(c, u0, v0, u1, v1, 18, s.wall)
        _age_window(c, s, 0.4, v1, 12)
        _age_window(c, s, 1.6, v1, 12)
        _age_window(c, s, u1, 0.6, 12, lit=False)
        _age_window(c, s, u1, 1.1, 12, lit=False)
        hip_roof(c, u0, v0, u1, v1, 18, 26, s.roof, overhang=0.1)
        x, y = _px(c, 1.0, 0.85, 40)
        c.draw.rectangle([x - 1, y - 1, x + 1, y], fill=(*DARK_LOAM, 255))
        _portico(c, 0.7, 1.3, v1, 0.32, 15, 3, s.roof, TIMBER_WALL, col=(PINE, TIMBER), recess=DARK_TIMBER)
        _lean_logs(c, 0.2, 1.9)
    elif n == "mediterranean":
        # Domus with a temple-front portico and a peristyle colonnade.
        u0, v0, u1, v1 = 0.15, 0.15, 1.8, 1.3
        shadow(c, u0, v0, u1, v1, 0.4)
        box(c, u0, v0, u1, v1, 20, s.wall)
        box(c, u0, v0, u1, v1, 5, s.base)
        _age_window(c, s, u1, 0.5, 15, lit=False)
        _age_window(c, s, u1, 0.95, 15, lit=False)
        hip_roof(c, u0, v0, u1, v1, 20, 8, s.roof, overhang=0.08)
        # Peristyle: a garden open to the sky, ringed by columns.
        a0, b0, a1, b1 = 0.65, 0.45, 1.35, 0.95
        c.poly([c.p(a0, b0, 25), c.p(a1, b0, 25), c.p(a1, b1, 25), c.p(a0, b1, 25)], OUTLINE)
        c.poly([c.p(a0 + 0.05, b0 + 0.05, 22), c.p(a1, b0 + 0.05, 22), c.p(a1, b1, 22), c.p(a0 + 0.05, b1, 22)],
               LEAF)
        for k in range(4):
            x, y = _px(c, a0 + 0.08 + (a1 - a0 - 0.12) * k / 3, b1, 22)
            c.line([(x, y), (x, y - 3)], CREAM)
        x, y = _px(c, (a0 + a1) / 2, (b0 + b1) / 2, 22)
        c.dot((x, y), HIGHLIGHT_WATER)
        c.dot((x + 1, y), HIGHLIGHT_WATER)
        _portico(c, 0.45, 1.35, v1, 0.42, 18, 4, s.roof, TRAVERTINE)
        amphora(c, 0.2, 1.9)
    elif n == "east-asian":
        # Great timber hall on a tall stone podium, red columns, tiled roof.
        box(c, 0.1, 0.2, 1.9, 1.75, 6, STONE_WALL)
        flat_top(c, 0.1, 0.2, 1.9, 1.75, 6, LIGHT_STONE)
        box(c, 0.75, 1.75, 1.15, 1.9, 3, STONE_WALL)
        flat_top(c, 0.75, 1.75, 1.15, 1.9, 3, LIGHT_STONE)
        u0, v0, u1, v1 = 0.3, 0.4, 1.7, 1.45
        _face(c, "lit", u0, u1, v1, 6, 22, DARK_TIMBER)
        box(c, u0, v0, u1, v1 - 0.12, 22, s.wall, z0=6)
        _columns(c, u0, u1, v1, 6, 22, 5, SUN_TERRACOTTA, TERRACOTTA)
        _columns(c, u1, u1, v0 + 0.05, 6, 22, 1, SUN_TERRACOTTA, TERRACOTTA)
        flared_roof(c, u0, v0, u1, v1, 22, 20, DARK_TILE_ROOF, overhang=0.26, lift=5)
    else:
        # Two-storey mud-brick house fronted by a columned porch (talar).
        u0, v0, u1, v1 = 0.2, 0.2, 1.8, 1.35
        shadow(c, u0, v0, u1, v1, 0.4)
        box(c, u0, v0, u1, v1, 30, s.wall)
        _vigas(c, u0, v0, u1, v1, 28)
        _vigas(c, u0, v0, u1, v1, 16)
        for z in (9, 22):
            _age_window(c, s, u1, 0.55, z, lit=False)
            _age_window(c, s, u1, 1.0, z, lit=False)
        _age_window(c, s, 0.45, v1, 22)
        _age_window(c, s, 1.55, v1, 22)
        _age_roof(c, s, u0, v0, u1, v1, 30, 0)
        # Talar: timber columns carrying a flat roof terrace.
        a0, a1 = 0.6, 1.5
        _face(c, "lit", a0, a1, v1, 0, 15, MEDIUM_LOAM)
        _age_door(c, s, 1.05, v1, height=8)
        _columns(c, a0, a1, v1 + 0.35, 0, 15, 4, PINE, TIMBER)
        box(c, a0 - 0.05, v1, a1 + 0.05, v1 + 0.4, 18, s.wall, z0=15)
        parapet(c, a0 - 0.05, v1, a1 + 0.05, v1 + 0.4, 18, s.wall, height=2, rim=0.05, cap=s.trim,
                deck=s.wall.shade)
        palm(c, 0.1, 1.85, 22)


# Renaissance ----------------------------------------------------------

def _renaissance_1(c: Canvas, s: AgeStyle) -> None:
    n = s.name
    if n == "northern-european":
        u0, v0, u1, v1 = 0.35, 0.25, 1.55, 1.6
        shadow(c, u0, v0, u1, v1)
        box(c, u0, v0, u1, v1, 26, s.wall)
        _cornice(c, u0, v0, u1, v1, 12, s.trim)
        _age_door(c, s, 0.7, v1, height=8)
        _age_window(c, s, 1.2, v1, 7)
        for uu in (0.6, 0.95, 1.3):
            _age_window(c, s, uu, v1, 20)
        for vv in (0.6, 1.05):
            _age_window(c, s, u1, vv, 19, lit=False)
            _age_window(c, s, u1, vv, 7, lit=False)
        gable_roof(c, u0, v0, u1, v1, 26, 18, s.roof, s.wall, axis="v")
        _stepped_gable(c, u0, u1, v1, 26, 18, s.wall)
        chimney(c, 0.8, 0.45, 34, 50)
    elif n == "mediterranean":
        u0, v0, u1, v1 = 0.25, 0.4, 1.7, 1.6
        shadow(c, u0, v0, u1, v1)
        box(c, u0, v0, u1, v1, 26, s.wall)
        box(c, u0, v0, u1, v1, 8, s.base)
        _cornice(c, u0, v0, u1, v1, 8, LIGHT_STONE)
        _age_door(c, s, 0.6, v1, height=7)
        _age_window(c, s, 1.1, v1, 4)
        _age_window(c, s, 1.45, v1, 4)
        for uu in (0.55, 1.0, 1.45):
            _age_window(c, s, uu, v1, 18)
        _age_window(c, s, u1, 0.75, 17, lit=False)
        _age_window(c, s, u1, 1.25, 17, lit=False)
        box(c, u0 - 0.04, v0 - 0.04, u1 + 0.04, v1 + 0.04, 28, Material(CREAM, LIGHT_STONE), z0=25)
        hip_roof(c, u0, v0, u1, v1, 28, 7, s.roof, overhang=0.08)
        amphora(c, 1.85, 1.85)
    elif n == "east-asian":
        # Two-storey townhouse: dark lattice shopfront, white upper
        # storey, a pent roof and a tiled gable roof.
        u0, v0, u1, v1 = 0.25, 0.35, 1.7, 1.6
        shadow(c, u0, v0, u1, v1)
        box(c, u0, v0, u1, v1, 12, s.base)
        x0, y0 = c.p(u0, v1, 0)
        x1, _ = c.p(u1, v1, 0)
        for x in range(round(x0) + 2, round(x1) - 1, 2):
            yb = y0 + (x - x0) * 0.5
            c.line([(x, yb - 2), (x, yb - 10)], PINE)
        flared_roof(c, u0, v0, u1, v1, 12, 4, s.roof, overhang=0.14, lift=1)
        box(c, u0 + 0.05, v0 + 0.05, u1 - 0.05, v1 - 0.05, 27, s.wall, z0=14)
        posts(c, u0 + 0.05, v0 + 0.05, u1 - 0.05, v1 - 0.05, 14, 27, DARK_TIMBER, step=0.35)
        for uu in (0.7, 1.25):
            _age_window(c, s, uu, v1 - 0.05, 21)
        _age_window(c, s, u1 - 0.05, 1.0, 20, lit=False)
        gable_roof(c, u0 + 0.05, v0 + 0.05, u1 - 0.05, v1 - 0.05, 27, 12, s.roof, s.wall, overhang=0.16)
    else:
        u0, v0, u1, v1 = 0.3, 0.3, 1.65, 1.65
        shadow(c, u0, v0, u1, v1)
        box(c, u0, v0, u1, v1, 26, s.wall)
        _cornice(c, u0, v0, u1, v1, 12, LIGHT_STONE)
        _age_door(c, s, 0.65, v1, height=8)
        _age_window(c, s, 1.35, v1, 6)
        mashrabiya(c, 1.15, v1, 15, half=0.2, height=9)
        _age_window(c, s, 0.6, v1, 19)
        _age_window(c, s, u1, 0.75, 19, lit=False)
        _age_window(c, s, u1, 1.25, 19, lit=False)
        _age_window(c, s, u1, 1.0, 6, lit=False)
        _age_roof(c, s, u0, v0, u1, v1, 26, 0)


def _renaissance_2(c: Canvas, s: AgeStyle) -> None:
    n = s.name
    if n == "northern-european":
        # Paired gable fronts of a merchant's house.
        u0, v0, u1, v1 = 0.2, 0.25, 1.75, 1.65
        shadow(c, u0, v0, u1, v1)
        box(c, u0, v0, u1, v1, 32, s.wall)
        box(c, u0, v0, u1, v1, 10, s.base)
        _cornice(c, u0, v0, u1, v1, 10, s.trim)
        _cornice(c, u0, v0, u1, v1, 21, s.trim)
        _age_door(c, s, 0.55, v1, height=8)
        for uu in (0.95, 1.4):
            _age_window(c, s, uu, v1, 5)
        for z in (16, 27):
            for uu in (0.4, 0.75, 1.2, 1.55):
                _age_window(c, s, uu, v1, z)
            for vv in (0.6, 1.1):
                _age_window(c, s, u1, vv, z - 1, lit=False)
        um = (u0 + u1) / 2
        gable_roof(c, um, v0, u1, v1, 32, 16, s.roof, s.wall, axis="v")
        gable_roof(c, u0, v0, um, v1, 32, 16, s.roof, s.wall, axis="v")
        _stepped_gable(c, u0, um, v1, 32, 16, s.wall)
        _stepped_gable(c, um, u1, v1, 32, 16, s.wall)
    elif n == "mediterranean":
        u0, v0, u1, v1 = 0.2, 0.2, 1.75, 1.7
        shadow(c, u0, v0, u1, v1)
        box(c, u0, v0, u1, v1, 34, s.wall)
        box(c, u0, v0, u1, v1, 11, s.base)
        _cornice(c, u0, v0, u1, v1, 11, LIGHT_STONE)
        for uu in (0.5, 0.9):
            x, y = _px(c, uu, v1, 0)
            arch(c, x, y - 1, 5, 8, DARK_TIMBER)
        _age_door(c, s, 1.35, v1, height=8)
        for z in (17, 27):
            for uu in (0.45, 0.95, 1.45):
                _age_window(c, s, uu, v1, z)
            _age_window(c, s, u1, 0.65, z - 1, lit=False)
            _age_window(c, s, u1, 1.2, z - 1, lit=False)
        box(c, u0 - 0.05, v0 - 0.05, u1 + 0.05, v1 + 0.05, 37, Material(CREAM, LIGHT_STONE), z0=33)
        hip_roof(c, u0, v0, u1, v1, 37, 7, s.roof, overhang=0.08)
    elif n == "east-asian":
        # Townhouse with a fire-proof white storehouse (kura) behind it.
        box(c, 1.1, 0.15, 1.8, 0.75, 30, WHITEWASH)
        _wainscot(c, 1.1, 0.15, 1.8, 0.75, 8)
        box(c, 1.1, 0.15, 1.8, 0.75, 30, WHITEWASH, z0=8)
        _age_window(c, s, 1.8, 0.45, 22, lit=False)
        gable_roof(c, 1.1, 0.15, 1.8, 0.75, 30, 10, s.roof, WHITEWASH, axis="v", overhang=0.1)
        u0, v0, u1, v1 = 0.2, 0.75, 1.75, 1.8
        shadow(c, u0, v0, u1, v1)
        box(c, u0, v0, u1, v1, 12, s.base)
        x0, y0 = c.p(u0, v1, 0)
        x1, _ = c.p(u1, v1, 0)
        for x in range(round(x0) + 2, round(x1) - 1, 2):
            yb = y0 + (x - x0) * 0.5
            c.line([(x, yb - 2), (x, yb - 10)], PINE)
        flared_roof(c, u0, v0, u1, v1, 12, 4, s.roof, overhang=0.14, lift=1)
        box(c, u0 + 0.05, v0 + 0.05, u1 - 0.05, v1 - 0.05, 28, s.wall, z0=14)
        posts(c, u0 + 0.05, v0 + 0.05, u1 - 0.05, v1 - 0.05, 14, 28, DARK_TIMBER, step=0.35)
        for uu in (0.6, 1.0, 1.4):
            _age_window(c, s, uu, v1 - 0.05, 21)
        gable_roof(c, u0 + 0.05, v0 + 0.05, u1 - 0.05, v1 - 0.05, 28, 11, s.roof, s.wall, overhang=0.16)
    else:
        u0, v0, u1, v1 = 0.2, 0.2, 1.75, 1.75
        shadow(c, u0, v0, u1, v1)
        box(c, u0, v0, u1, v1, 34, s.wall)
        _cornice(c, u0, v0, u1, v1, 12, LIGHT_STONE)
        _cornice(c, u0, v0, u1, v1, 23, LIGHT_STONE)
        _age_door(c, s, 0.55, v1, height=9)
        _age_window(c, s, 1.0, v1, 6)
        _age_window(c, s, 1.45, v1, 6)
        mashrabiya(c, 0.75, v1, 15, half=0.2, height=9)
        mashrabiya(c, 1.35, v1, 15, half=0.2, height=9)
        for uu in (0.5, 1.05, 1.55):
            _age_window(c, s, uu, v1, 29)
        for z in (6, 18, 29):
            _age_window(c, s, u1, 0.65, z, lit=False)
            _age_window(c, s, u1, 1.25, z, lit=False)
        _age_roof(c, s, u0, v0, u1, v1, 34, 0)


def _renaissance_3(c: Canvas, s: AgeStyle) -> None:
    n = s.name
    if n == "northern-european":
        # Guild house: a tall stepped gable with pilasters and cornices.
        u0, v0, u1, v1 = 0.2, 0.15, 1.75, 1.75
        shadow(c, u0, v0, u1, v1, 0.4)
        box(c, u0, v0, u1, v1, 40, s.wall)
        box(c, u0, v0, u1, v1, 12, s.base)
        _pilasters(c, s, u0 + 0.08, u1 - 0.08, v1, 12, 40, 4)
        for z in (12, 26, 40):
            _cornice(c, u0, v0, u1, v1, z, s.trim)
        _age_door(c, s, 0.75, v1, height=9)
        _age_door(c, s, 1.2, v1, height=9)
        for z in (20, 34):
            for uu in (0.45, 0.97, 1.5):
                _age_window(c, s, uu, v1, z)
            for vv in (0.5, 0.95, 1.4):
                _age_window(c, s, u1, vv, z - 1, lit=False)
        gable_roof(c, u0, v0, u1, v1, 40, 22, s.roof, s.wall, axis="v")
        _stepped_gable(c, u0, u1, v1, 40, 22, s.wall, steps=4)
        chimney(c, 0.6, 0.3, 46, 66)
    elif n == "mediterranean":
        # Palazzo: rusticated base, pilastered piano nobile, a deep
        # cornice and a roof-top loggia.
        t0, t1 = 0.25, 0.8
        box(c, t0, t0, t1, t1, 56, s.wall)
        for k in (0.33, 0.66):
            x, y = _px(c, t0 + (t1 - t0) * k, t1, 47)
            arch(c, x, y, 3, 6, DARK_TIMBER)
            x, y = _px(c, t1, t0 + (t1 - t0) * k, 47)
            arch(c, x, y, 3, 6, OUTLINE)
        hip_roof(c, t0, t0, t1, t1, 56, 6, s.roof, overhang=0.06)
        u0, v0, u1, v1 = 0.15, 0.15, 1.8, 1.8
        shadow(c, u0, v0, u1, v1, 0.4)
        box(c, u0, v0, u1, v1, 40, s.wall)
        box(c, u0, v0, u1, v1, 13, s.base)
        for z in (4, 8):
            _face_line(c, "lit", u0, u1, v1, z, STONE)
        _cornice(c, u0, v0, u1, v1, 13, LIGHT_STONE)
        _pilasters(c, s, u0 + 0.1, u1 - 0.1, v1, 13, 38, 4)
        x, y = _px(c, 0.95, v1, 0)
        arch(c, x, y - 1, 7, 11, LIGHT_STONE)
        arch(c, x, y - 1, 5, 10, DARK_TIMBER)
        for z in (21, 32):
            for uu in (0.45, 0.8, 1.15, 1.5):
                _age_window(c, s, uu, v1, z)
            for vv in (0.55, 1.0, 1.45):
                _age_window(c, s, u1, vv, z - 1, lit=False)
        box(c, u0 - 0.06, v0 - 0.06, u1 + 0.06, v1 + 0.06, 43, Material(CREAM, LIGHT_STONE), z0=39)
        hip_roof(c, u0, v0, u1, v1, 43, 7, s.roof, overhang=0.08)
    elif n == "east-asian":
        # Merchant's residence: two full storeys over a stone base, a
        # pent roof between them and a big tiled hip-and-gable roof.
        box(c, 0.1, 0.15, 1.9, 1.85, 4, STONE_WALL)
        flat_top(c, 0.1, 0.15, 1.9, 1.85, 4, LIGHT_STONE)
        u0, v0, u1, v1 = 0.2, 0.25, 1.8, 1.75
        box(c, u0, v0, u1, v1, 17, s.base, z0=4)
        x0, y0 = c.p(u0, v1, 4)
        x1, _ = c.p(u1, v1, 4)
        for x in range(round(x0) + 2, round(x1) - 1, 2):
            yb = y0 + (x - x0) * 0.5
            c.line([(x, yb - 2), (x, yb - 11)], PINE)
        _age_door(c, s, 0.6, v1, height=10, z0=4)
        flared_roof(c, u0, v0, u1, v1, 17, 5, s.roof, overhang=0.14, lift=2)
        a0, b0, a1, b1 = 0.3, 0.35, 1.7, 1.65
        z = _skirt_top(17, 5, 0.75, 0.65, 0.14)
        box(c, a0, b0, a1, b1, z + 16, s.wall, z0=z)
        posts(c, a0, b0, a1, b1, z, z + 16, DARK_TIMBER, step=0.35)
        for uu in (0.55, 0.9, 1.25, 1.55):
            _age_window(c, s, uu, b1, z + 10)
        for vv in (0.7, 1.3):
            _age_window(c, s, a1, vv, z + 9, lit=False)
        flared_roof(c, a0, b0, a1, b1, z + 16, 18, s.roof, overhang=0.2, lift=4)
        x, y = _px(c, 1.0, 1.0, z + 16 + 14)
        c.draw.polygon([(x - 3, y + 2), (x, y - 3), (x + 3, y + 2)], fill=(*s.wall.lit, 255),
                       outline=(*OUTLINE, 255))
    else:
        # Stone mansion with mashrabiya bays, a cornice and a small dome.
        u0, v0, u1, v1 = 0.15, 0.15, 1.8, 1.8
        shadow(c, u0, v0, u1, v1, 0.4)
        box(c, u0, v0, u1, v1, 38, s.wall)
        box(c, u0, v0, u1, v1, 12, s.base)
        _cornice(c, u0, v0, u1, v1, 12, LIGHT_STONE)
        _cornice(c, u0, v0, u1, v1, 25, LIGHT_STONE)
        x, y = _px(c, 0.6, v1, 0)
        arch(c, x, y - 1, 7, 11, s.culture.accent)
        arch(c, x, y - 1, 5, 10, DARK_TIMBER)
        _age_window(c, s, 1.1, v1, 6)
        _age_window(c, s, 1.5, v1, 6)
        mashrabiya(c, 0.65, v1, 16, half=0.2, height=8)
        mashrabiya(c, 1.35, v1, 16, half=0.2, height=8)
        mashrabiya(c, 1.0, v1, 28, half=0.2, height=8)
        for uu in (0.5, 1.5):
            _age_window(c, s, uu, v1, 32)
        for z in (6, 19, 32):
            _age_window(c, s, u1, 0.6, z, lit=False)
            _age_window(c, s, u1, 1.3, z, lit=False)
        _age_roof(c, s, u0, v0, u1, v1, 38, 0)
        dome(c, 0.75, 0.75, 41, 12, 4, TILE_DOME, s.wall, band=s.culture.accent)


# Industrial -----------------------------------------------------------

def _industrial_1(c: Canvas, s: AgeStyle) -> None:
    n = s.name
    if n == "northern-european":
        # A pair of brick terraced cottages under one slate roof.
        u0, v0, u1, v1 = 0.15, 0.45, 1.85, 1.5
        shadow(c, u0, v0, u1, v1)
        box(c, u0, v0, u1, v1, 20, s.wall)
        _brickwork(c, u0, v0, u1, v1, 0, 20)
        um = (u0 + u1) / 2
        c.line([c.p(um, v1, 0), c.p(um, v1, 20)], s.trim)
        for uu in (0.4, 1.1):
            _age_door(c, s, uu, v1, height=8)
        for uu in (0.75, 1.5):
            _age_window(c, s, uu, v1, 6)
        for uu in (0.45, 0.75, 1.15, 1.5):
            _age_window(c, s, uu, v1, 16)
        _age_window(c, s, u1, 1.0, 15, lit=False)
        gable_roof(c, u0, v0, u1, v1, 20, 12, s.roof, s.wall, axis="u")
        for uu in (0.3, um - 0.08, 1.55):
            _brick_chimney(c, uu, 0.9, 26, 38)
    elif n == "mediterranean":
        u0, v0, u1, v1 = 0.25, 0.4, 1.7, 1.6
        shadow(c, u0, v0, u1, v1)
        box(c, u0, v0, u1, v1, 24, s.wall)
        _brickwork(c, u0, v0, u1, v1, 0, 24)
        _cornice(c, u0, v0, u1, v1, 23, s.trim)
        _age_door(c, s, 0.6, v1, height=8)
        _age_window(c, s, 1.1, v1, 6)
        _age_window(c, s, 1.45, v1, 6)
        for uu in (0.6, 1.1, 1.45):
            _age_window(c, s, uu, v1, 18)
        _age_window(c, s, u1, 0.75, 17, lit=False)
        _age_window(c, s, u1, 1.25, 17, lit=False)
        _balcony(c, "lit", 0.95, 1.6, v1, 13, rail=OUTLINE, slab=LIGHT_STONE)
        hip_roof(c, u0, v0, u1, v1, 24, 7, s.roof, overhang=0.08)
        _brick_chimney(c, 1.2, 0.65, 26, 38)
        _brick_chimney(c, 0.5, 0.65, 26, 36)
    elif n == "east-asian":
        u0, v0, u1, v1 = 0.25, 0.45, 1.7, 1.55
        shadow(c, u0, v0, u1, v1)
        box(c, u0, v0, u1, v1, 3, s.base)
        box(c, u0, v0, u1, v1, 20, s.wall, z0=3)
        _brickwork(c, u0, v0, u1, v1, 3, 20)
        _age_door(c, s, 0.65, v1, height=9, z0=3)
        for uu in (1.1, 1.45):
            _age_window(c, s, uu, v1, 13)
        _age_window(c, s, u1, 0.8, 13, lit=False)
        _age_window(c, s, u1, 1.25, 13, lit=False)
        flared_roof(c, u0, v0, u1, v1, 20, 11, s.roof, overhang=0.18, lift=3)
        _brick_chimney(c, 1.3, 0.75, 24, 40)
    else:
        u0, v0, u1, v1 = 0.3, 0.3, 1.65, 1.65
        shadow(c, u0, v0, u1, v1)
        box(c, u0, v0, u1, v1, 22, s.wall)
        _brickwork(c, u0, v0, u1, v1, 0, 22)
        _age_door(c, s, 0.65, v1, height=8)
        _age_window(c, s, 1.2, v1, 7)
        _age_window(c, s, 0.75, v1, 17)
        _age_window(c, s, 1.3, v1, 17)
        _age_window(c, s, u1, 0.75, 16, lit=False)
        _age_window(c, s, u1, 1.25, 16, lit=False)
        awning(c, 1.0, 1.5, v1, 11)
        _age_roof(c, s, u0, v0, u1, v1, 22, 0)
        _brick_chimney(c, 0.5, 0.5, 25, 36)
        _brick_chimney(c, 1.3, 0.5, 25, 34)


def _industrial_2(c: Canvas, s: AgeStyle) -> None:
    n = s.name
    if n == "northern-european":
        # Three-storey brick terrace with bay windows.
        u0, v0, u1, v1 = 0.15, 0.35, 1.85, 1.6
        shadow(c, u0, v0, u1, v1)
        box(c, u0, v0, u1, v1, 30, s.wall)
        _brickwork(c, u0, v0, u1, v1, 0, 30)
        um = (u0 + u1) / 2
        c.line([c.p(um, v1, 0), c.p(um, v1, 30)], s.trim)
        for uu in (0.35, 1.2):
            _age_door(c, s, uu, v1, height=8)
        for a in (0.55, 1.4):
            box(c, a, v1, a + 0.3, v1 + 0.12, 13, BRICK)
            flat_top(c, a, v1, a + 0.3, v1 + 0.12, 13, SLATE)
            _age_window(c, s, a + 0.15, v1 + 0.12, 7)
        for z in (17, 26):
            for uu in (0.4, 0.75, 1.25, 1.6):
                _age_window(c, s, uu, v1, z)
            _age_window(c, s, u1, 0.95, z - 1, lit=False)
        gable_roof(c, u0, v0, u1, v1, 30, 12, s.roof, s.wall, axis="u")
        for uu in (0.25, um - 0.08, 1.6):
            _brick_chimney(c, uu, 0.85, 36, 48)
    elif n == "mediterranean":
        u0, v0, u1, v1 = 0.2, 0.2, 1.75, 1.7
        shadow(c, u0, v0, u1, v1)
        box(c, u0, v0, u1, v1, 32, s.wall)
        _brickwork(c, u0, v0, u1, v1, 0, 32)
        box(c, u0, v0, u1, v1, 10, s.base)
        _cornice(c, u0, v0, u1, v1, 31, s.trim)
        for uu in (0.5, 0.9):
            x, y = _px(c, uu, v1, 0)
            arch(c, x, y - 1, 5, 8, DARK_TIMBER)
        _age_door(c, s, 1.4, v1, height=8)
        for z in (17, 26):
            for uu in (0.45, 0.95, 1.45):
                _age_window(c, s, uu, v1, z)
            _age_window(c, s, u1, 0.65, z - 1, lit=False)
            _age_window(c, s, u1, 1.2, z - 1, lit=False)
        _balcony(c, "lit", 0.3, 1.65, v1, 21, rail=OUTLINE)
        hip_roof(c, u0, v0, u1, v1, 32, 7, s.roof, overhang=0.08)
        for uu in (0.45, 1.0, 1.45):
            _brick_chimney(c, uu, 0.5, 34, 46)
    elif n == "east-asian":
        u0, v0, u1, v1 = 0.2, 0.3, 1.75, 1.65
        shadow(c, u0, v0, u1, v1)
        box(c, u0, v0, u1, v1, 3, s.base)
        box(c, u0, v0, u1, v1, 28, s.wall, z0=3)
        _brickwork(c, u0, v0, u1, v1, 3, 28)
        _cornice(c, u0, v0, u1, v1, 15, s.trim)
        _age_door(c, s, 0.55, v1, height=9, z0=3)
        for uu in (1.0, 1.45):
            _age_window(c, s, uu, v1, 11)
        for uu in (0.55, 1.0, 1.45):
            _age_window(c, s, uu, v1, 23)
        for z in (11, 23):
            _age_window(c, s, u1, 0.75, z, lit=False)
            _age_window(c, s, u1, 1.25, z, lit=False)
        _balcony(c, "lit", 0.35, 1.6, v1, 16, rail=DARK_TIMBER)
        flared_roof(c, u0, v0, u1, v1, 28, 13, s.roof, overhang=0.18, lift=3)
        _brick_chimney(c, 1.35, 0.6, 32, 50)
        _brick_chimney(c, 0.45, 0.6, 32, 46)
    else:
        u0, v0, u1, v1 = 0.2, 0.2, 1.75, 1.75
        shadow(c, u0, v0, u1, v1)
        box(c, u0, v0, u1, v1, 32, s.wall)
        _brickwork(c, u0, v0, u1, v1, 0, 32)
        _cornice(c, u0, v0, u1, v1, 12, s.trim)
        for uu in (0.5, 0.9, 1.3):
            x, y = _px(c, uu, v1, 0)
            arch(c, x, y - 1, 5, 9, DARK_TIMBER)
            c.draw.line([(x - 3, y - 11), (x + 3, y - 11)], fill=(*s.trim, 255))
        for z in (18, 27):
            for uu in (0.5, 0.9, 1.3, 1.6):
                _age_window(c, s, uu, v1, z)
            _age_window(c, s, u1, 0.65, z - 1, lit=False)
            _age_window(c, s, u1, 1.25, z - 1, lit=False)
        _age_roof(c, s, u0, v0, u1, v1, 32, 0)
        for uu in (0.4, 0.9, 1.4):
            _brick_chimney(c, uu, 0.4, 35, 46)


def _industrial_3(c: Canvas, s: AgeStyle) -> None:
    n = s.name
    if n == "northern-european":
        # Tall brick townhouse with a slate mansard and dormers.
        u0, v0, u1, v1 = 0.2, 0.2, 1.75, 1.75
        shadow(c, u0, v0, u1, v1, 0.4)
        box(c, u0, v0, u1, v1, 40, s.wall)
        _brickwork(c, u0, v0, u1, v1, 0, 40)
        box(c, u0, v0, u1, v1, 10, s.base)
        for z in (10, 40):
            _cornice(c, u0, v0, u1, v1, z, s.trim)
        _age_door(c, s, 0.6, v1, height=8)
        _age_window(c, s, 1.05, v1, 5)
        _age_window(c, s, 1.45, v1, 5)
        for z in (17, 26, 35):
            for uu in (0.45, 0.85, 1.25, 1.55):
                _age_window(c, s, uu, v1, z)
            for vv in (0.55, 1.0, 1.45):
                _age_window(c, s, u1, vv, z - 1, lit=False)
        # Mansard: steep slate lower slope, then a low hip.
        box(c, u0 + 0.05, v0 + 0.05, u1 - 0.05, v1 - 0.05, 50, SLATE_ROOF, z0=40)
        for uu in (0.55, 1.0, 1.45):
            x, y = _px(c, uu, v1 - 0.05, 45)
            c.draw.rectangle([x - 2, y - 3, x + 2, y + 2], fill=(*LIGHT_STONE, 255))
            c.draw.rectangle([x - 1, y - 2, x + 1, y + 1], fill=(*DARK_TIMBER, 255))
        hip_roof(c, u0 + 0.05, v0 + 0.05, u1 - 0.05, v1 - 0.05, 50, 6, s.roof, overhang=0.04)
        for uu, vv in ((0.3, 0.35), (0.85, 0.3), (1.4, 0.35)):
            _brick_chimney(c, uu, vv, 50, 64)
    elif n == "mediterranean":
        u0, v0, u1, v1 = 0.15, 0.15, 1.8, 1.8
        shadow(c, u0, v0, u1, v1, 0.4)
        box(c, u0, v0, u1, v1, 44, s.wall)
        _brickwork(c, u0, v0, u1, v1, 0, 44)
        box(c, u0, v0, u1, v1, 11, s.base)
        _cornice(c, u0, v0, u1, v1, 11, s.trim)
        box(c, u0 - 0.05, v0 - 0.05, u1 + 0.05, v1 + 0.05, 46, STONE_WALL, z0=43)
        for uu in (0.5, 0.95, 1.4):
            x, y = _px(c, uu, v1, 0)
            arch(c, x, y - 1, 5, 9, DARK_TIMBER)
        for z in (18, 27, 36):
            for uu in (0.45, 0.85, 1.25, 1.6):
                _age_window(c, s, uu, v1, z)
            for vv in (0.55, 1.0, 1.45):
                _age_window(c, s, u1, vv, z - 1, lit=False)
        for z in (22, 31):
            _balcony(c, "lit", 0.3, 1.7, v1, z - 9, rail=OUTLINE)
        hip_roof(c, u0, v0, u1, v1, 46, 7, s.roof, overhang=0.08)
        for uu in (0.35, 0.9, 1.45):
            _brick_chimney(c, uu, 0.4, 48, 60)
    elif n == "east-asian":
        u0, v0, u1, v1 = 0.15, 0.2, 1.8, 1.75
        shadow(c, u0, v0, u1, v1, 0.4)
        box(c, u0, v0, u1, v1, 4, s.base)
        box(c, u0, v0, u1, v1, 40, s.wall, z0=4)
        _brickwork(c, u0, v0, u1, v1, 4, 40)
        for z in (16, 28):
            _cornice(c, u0, v0, u1, v1, z, s.trim)
        x, y = _px(c, 0.95, v1, 4)
        arch(c, x, y - 1, 7, 11, s.trim)
        arch(c, x, y - 1, 5, 10, DARK_TIMBER)
        for uu in (0.45, 1.45):
            _age_window(c, s, uu, v1, 11)
        for z in (23, 35):
            for uu in (0.45, 0.8, 1.15, 1.5):
                _age_window(c, s, uu, v1, z)
            for vv in (0.6, 1.0, 1.4):
                _age_window(c, s, u1, vv, z - 1, lit=False)
        flared_roof(c, u0, v0, u1, v1, 40, 14, s.roof, overhang=0.2, lift=4)
        # Clock turret on the ridge.
        box(c, 0.85, 0.85, 1.1, 1.1, 64, s.wall, z0=48)
        x, y = _px(c, 0.975, 1.1, 58)
        c.draw.ellipse([x - 2, y - 2, x + 2, y + 2], fill=(*CREAM, 255), outline=(*OUTLINE, 255))
        flared_roof(c, 0.85, 0.85, 1.1, 1.1, 64, 7, s.roof, overhang=0.08, lift=2)
        _brick_chimney(c, 1.45, 0.45, 44, 58)
    else:
        u0, v0, u1, v1 = 0.15, 0.15, 1.8, 1.8
        shadow(c, u0, v0, u1, v1, 0.4)
        box(c, u0, v0, u1, v1, 44, s.wall)
        _brickwork(c, u0, v0, u1, v1, 0, 44)
        _cornice(c, u0, v0, u1, v1, 13, s.trim)
        for uu in (0.4, 0.75, 1.1, 1.45):
            x, y = _px(c, uu, v1, 0)
            arch(c, x, y - 1, 5, 10, DARK_TIMBER)
            c.draw.line([(x - 3, y - 12), (x + 3, y - 12)], fill=(*s.trim, 255))
        for z in (20, 29, 38):
            for uu in (0.45, 0.85, 1.25, 1.6):
                _age_window(c, s, uu, v1, z)
            for vv in (0.55, 1.0, 1.45):
                _age_window(c, s, u1, vv, z - 1, lit=False)
        mashrabiya(c, 1.0, v1, 23, half=0.22, height=8)
        _age_roof(c, s, u0, v0, u1, v1, 44, 0)
        for uu in (0.35, 0.8, 1.25):
            _brick_chimney(c, uu, 0.35, 47, 60)


# Modern ---------------------------------------------------------------

def _modern_accent(c: Canvas, s: AgeStyle, u0: float, v0: float, u1: float, v1: float, z: float) -> None:
    """The culture's mark on a modern flat roof."""
    n = s.name
    if n == "mediterranean":
        # Roof terrace pergola and a parasol.
        a0, a1, b0, b1 = u0 + 0.15, u0 + 0.6, v0 + 0.15, v0 + 0.6
        for uu, vv in ((a0, b1), (a1, b1), (a1, b0)):
            c.line([c.p(uu, vv, z), c.p(uu, vv, z + 7)], PINE)
        for k in range(4):
            vv = b0 + (b1 - b0) * k / 3
            c.line([c.p(a0, vv, z + 7), c.p(a1, vv, z + 7)], TIMBER)
        x, y = _px(c, (u0 + u1) / 2 + 0.25, (v0 + v1) / 2 + 0.2, z)
        c.line([(x, y), (x, y - 7)], DARK_TIMBER)
        c.poly([(x - 5, y - 6), (x + 5, y - 6), (x, y - 9)], s.trim)
    elif n == "east-asian":
        # A flared tiled canopy over the roof edge.
        flared_roof(c, u0 + 0.1, v0 + 0.1, u1 - 0.1, v1 - 0.1, z + 2, 6, s.roof, overhang=0.14, lift=3)
    elif n == "middle-eastern":
        a = min(u1 - u0, v1 - v0) * 0.18
        dome(c, u0 + a + 0.15, v0 + a + 0.15, z, 7, 3, TILE_DOME, CONCRETE)
    else:
        # Solar panels on the flat roof.
        a0, a1, b0, b1 = u0 + 0.2, u1 - 0.25, v0 + 0.2, v0 + 0.55
        c.poly([c.p(a0, b0, z + 4), c.p(a1, b0, z + 4), c.p(a1, b1, z + 1), c.p(a0, b1, z + 1)], DEEP_WATER)
        c.line([c.p(a0, b1, z + 1), c.p(a1, b1, z + 1)], OUTLINE)
        c.line([c.p((a0 + a1) / 2, b0, z + 4), c.p((a0 + a1) / 2, b1, z + 1)], MID_WATER)


def _modern_base(c: Canvas, s: AgeStyle, u0: float, v0: float, u1: float, v1: float, z: float) -> None:
    """A culture-tinted lower storey or cladding panel."""
    if s.base is CONCRETE:
        return
    box(c, u0, v0, u1, v1, z, s.base)
    if s.name == "northern-european":
        x0, y0 = c.p(u0, v1, 0)
        x1, _ = c.p(u1, v1, 0)
        for x in range(round(x0) + 2, round(x1) - 1, 3):
            yb = y0 + (x - x0) * 0.5
            c.line([(x, yb - 1), (x, yb - z + 1)], TIMBER)
    elif s.name == "middle-eastern":
        _face_line(c, "lit", u0, u1, v1, z - 1, s.trim)
        _face_line(c, "shade", v0, v1, u1, z - 1, DEEP_WATER)


def _screen(c: Canvas, u0: float, u1: float, v: float, z0: float, z1: float) -> None:
    """A pierced sun screen (modern mashrabiya) over the lit wall."""
    _face(c, "lit", u0, u1, v, z0, z1, PALE_SAND)
    x0, y0 = c.p(u0, v, z0)
    x1, _ = c.p(u1, v, z0)
    for x in range(round(x0) + 1, round(x1)):
        yb = y0 + (x - x0) * 0.5
        for k in range(1, int(z1 - z0)):
            if (x + k) % 3 == 0:
                c.dot((x, yb - k), MID_WATER)


def _modern_1(c: Canvas, s: AgeStyle) -> None:
    u0, v0, u1, v1 = 0.25, 0.35, 1.7, 1.6
    shadow(c, u0, v0, u1, v1)
    box(c, u0, v0, u1, v1, 20, s.wall)
    _modern_base(c, s, u0, v0, u1, v1, 10)
    _glass(c, "lit", 0.95, 1.6, v1, 2, 8)
    _age_door(c, s, 0.55, v1, height=8)
    if s.name == "middle-eastern":
        _screen(c, 0.35, 1.0, v1, 12, 18)
        _glass(c, "lit", 1.1, 1.6, v1, 12, 18)
    else:
        _glass(c, "lit", 0.35, 1.6, v1, 12, 18)
    _glass(c, "shade", 0.5, 1.45, u1, 12, 18)
    _glass(c, "shade", 0.8, 1.4, u1, 2, 8)
    _age_roof(c, s, u0, v0, u1, v1, 20, 0)
    _modern_accent(c, s, u0, v0, u1, v1, 20)
    # Car port slab on a slim post.
    box(c, 1.75, 0.5, 1.95, 1.35, 1, CONCRETE)
    c.line([c.p(1.95, 1.3, 0), c.p(1.95, 1.3, 9)], LIGHT_STONE)
    box(c, 1.7, 0.45, 1.98, 1.38, 11, CONCRETE, z0=9)
    flat_top(c, 1.7, 0.45, 1.98, 1.38, 11, LIGHT_STONE)


def _modern_2(c: Canvas, s: AgeStyle) -> None:
    # L-shaped villa: a three-storey wing behind a two-storey wing.
    a0, b0, a1, b1 = 0.2, 0.2, 1.05, 1.0
    box(c, a0, b0, a1, b1, 32, s.wall)
    _glass(c, "shade", b0 + 0.15, b1 - 0.1, a1, 24, 30)
    _age_roof(c, s, a0, b0, a1, b1, 32, 0)
    _modern_accent(c, s, a0, b0, a1, b1, 32)
    u0, v0, u1, v1 = 0.2, 0.75, 1.8, 1.7
    shadow(c, u0, v0, u1, v1)
    box(c, u0, v0, u1, v1, 22, s.wall)
    _modern_base(c, s, u0, v0, u1, v1, 11)
    _age_door(c, s, 0.5, v1, height=8)
    _glass(c, "lit", 0.8, 1.7, v1, 2, 9)
    if s.name == "middle-eastern":
        _screen(c, 0.3, 1.0, v1, 13, 20)
        _glass(c, "lit", 1.1, 1.7, v1, 13, 20)
    else:
        _glass(c, "lit", 0.3, 1.7, v1, 13, 20)
    _glass(c, "shade", 0.9, 1.6, u1, 13, 20)
    _glass(c, "shade", 0.9, 1.6, u1, 2, 9)
    _balcony(c, "lit", 0.9, 1.7, v1, 12, rail=GLINT)
    _age_roof(c, s, u0, v0, u1, v1, 22, 0)
    if s.name == "mediterranean":
        # Rooftop pool on the lower wing.
        c.poly([c.p(1.15, 0.95, 22), c.p(1.65, 0.95, 22), c.p(1.65, 1.5, 22), c.p(1.15, 1.5, 22)], HIGHLIGHT_WATER)
        c.line([c.p(1.15, 0.95, 22), c.p(1.65, 0.95, 22)], MID_WATER)


def _modern_3(c: Canvas, s: AgeStyle) -> None:
    # A small apartment block: five storeys with stacked balconies.
    u0, v0, u1, v1 = 0.25, 0.25, 1.75, 1.75
    shadow(c, u0, v0, u1, v1, 0.4)
    top = 52
    box(c, u0, v0, u1, v1, top, s.wall)
    _modern_base(c, s, u0, v0, u1, v1, 10)
    _age_door(c, s, 0.55, v1, height=8)
    _glass(c, "lit", 0.85, 1.65, v1, 2, 8)
    _glass(c, "shade", 0.4, 1.6, u1, 2, 8)
    for z in (12, 22, 32, 42):
        if s.name == "middle-eastern":
            _screen(c, 0.35, 0.85, v1, z + 1, z + 8)
            _glass(c, "lit", 0.95, 1.65, v1, z + 1, z + 8)
        else:
            _glass(c, "lit", 0.35, 1.65, v1, z + 1, z + 8)
        _glass(c, "shade", 0.4, 1.6, u1, z + 1, z + 8)
        _balcony(c, "lit", 0.9, 1.6, v1, z, rail=GLINT if s.name != "east-asian" else DARK_TIMBER)
        _balcony(c, "shade", 0.45, 0.95, u1, z, rail=GLINT)
    _age_roof(c, s, u0, v0, u1, v1, top, 0)
    if s.name == "east-asian":
        _modern_accent(c, s, u0, v0, u1, v1, top)
        return
    box(c, 0.45, 0.45, 0.9, 0.85, top + 7, CONCRETE, z0=top)
    flat_top(c, 0.45, 0.45, 0.9, 0.85, top + 7, LIGHT_STONE)
    _modern_accent(c, s, 0.85, 0.85, u1, u1, top)


_AGE_DRAWERS: dict[str, tuple[Callable[[Canvas, AgeStyle], None], ...]] = {
    "antiquity": (_antiquity_1, _antiquity_2, _antiquity_3),
    "renaissance": (_renaissance_1, _renaissance_2, _renaissance_3),
    "industrial": (_industrial_1, _industrial_2, _industrial_3),
    "modern": (_modern_1, _modern_2, _modern_3),
}


def draw_age_house(age: str, tier: int, culture: str = "northern-european") -> Image.Image:
    """The house look for `tier` (1–3) of `culture` in `age`: same 2×2
    footprint and bottom anchor as `building-house`, trimmed to the
    smoke-plume headroom."""
    c = Canvas(2, 2, 140)
    yard(c)
    _AGE_DRAWERS[age][tier - 1](c, age_style(culture, age))
    return _trim(c.img)


def age_house_name(age: str, tier: int, culture: str = "northern-european") -> str:
    tier_part = "" if tier == 1 else f"-tier{tier}"
    culture_part = "" if culture == NORTHERN_EUROPEAN.culture else f"-{culture}"
    return f"building-house{tier_part}-{age}{culture_part}"


# Quern house ----------------------------------------------------------

def _millstone(c: Canvas, u: float, v: float, handle: float) -> None:
    """A hand quern on a low stone block: two stacked stones, the upper
    one turned by an upright handle at angle `handle` (radians)."""
    box(c, u - 0.22, v - 0.22, u + 0.22, v + 0.22, 4, STONE_WALL)
    flat_top(c, u - 0.22, v - 0.22, u + 0.22, v + 0.22, 4, LIGHT_STONE)
    x, y = _px(c, u, v, 4)
    c.draw.ellipse([x - 10, y - 5, x + 10, y + 4], fill=(*SHADOW_STONE, 255), outline=(*OUTLINE, 255))
    c.draw.ellipse([x - 9, y - 9, x + 9, y + 1], fill=(*STONE, 255), outline=(*OUTLINE, 255))
    c.draw.ellipse([x - 8, y - 9, x + 7, y - 2], fill=(*LIGHT_STONE, 255))
    c.draw.ellipse([x - 2, y - 6, x + 1, y - 4], fill=(*OUTLINE, 255))
    # Flour spilling from the lower stone's lip.
    for dx, dy, fill in ((9, 3, CREAM), (10, 4, PALE_SAND), (8, 4, CREAM), (11, 5, PALE_SAND)):
        c.dot((x + dx, y + dy), fill)
    hx, hy = round(x + math.cos(handle) * 6), round(y - 5 + math.sin(handle) * 2)
    c.line([(hx, hy), (hx, hy - 8)], DARK_TIMBER, width=2)
    c.dot((hx, hy - 8), PINE)


QUERN_HANDLE = (math.pi * 0.85, math.pi * 0.15)


def _quern_house(stage: str, handle: float = QUERN_HANDLE[0]) -> Image.Image:
    c = Canvas(2, 2, 44)
    yard(c)
    b = Block(0.2, 0.2, 1.25, 1.15, 12, MUD_BRICK, THATCH_ROOF, "gable_u", 10)
    draw_block(c, b, stage)
    if stage in ("walls", "done"):
        x, y = _px(c, 0.6, 1.15, 0)
        c.draw.rectangle([x - 1, y - 7, x + 1, y - 1], fill=(*OUTLINE, 255))
        x, y = _px(c, 1.25, 0.65, 8)
        c.draw.rectangle([x, y - 1, x + 1, y], fill=(*OUTLINE, 255))
    if stage == "done":
        for u, v in ((0.3, 1.45), (0.5, 1.55), (0.35, 1.75), (0.6, 1.8)):
            sack(c, u, v)
        _millstone(c, 1.45, 1.5, handle)
        sack(c, 1.8, 0.95)
        sack(c, 1.9, 1.15)
    return c.img


def draw_quern_frame(frame: int) -> Image.Image:
    """Operational quern house: the millstone handle goes round."""
    return _crop_to_idle(_quern_house("done", QUERN_HANDLE[frame % len(QUERN_HANDLE)]), _quern_house("done"))


# Culture luxury chains (`add-culture-content` D6) ----------------------
#
# Each culture's garden and producer, drawn in that culture's style.
# Gardens are fields of tall plants behind a small shed; producers carry
# a prop that names the luxury (casks, wine press, kettle, roasting drum).

def _garden_plot(c: Canvas, stage: str) -> None:
    """Tilled ground for the plants and a low fence along its near edges."""
    _field_rows(c, 0.05, 0.75, 1.95, 1.95, LIGHT_LOAM, MEDIUM_LOAM if stage == "pad" else DARK_LOAM)
    if stage == "pad":
        return
    c.line([c.p(0.05, 1.95, 3), c.p(1.95, 1.95, 3), c.p(1.95, 0.75, 3)], TIMBER)
    c.line([c.p(0.05, 1.95, 0), c.p(1.95, 1.95, 0), c.p(1.95, 0.75, 0)], OUTLINE)
    for u in (0.05, 0.5, 1.0, 1.5, 1.95):
        c.line([c.p(u, 1.95, 0), c.p(u, 1.95, 4)], DARK_TIMBER)


# How far the plants have grown after the pad: bare stakes, young, harvest.
GROWTH = {"frame": 0.0, "walls": 0.5, "done": 1.0}
Plant = Callable[[Canvas, float, float, float], None]


def _hop_bine(c: Canvas, u: float, v: float, grown: float) -> None:
    """A tall pole with a hop bine climbing it, cones hanging along it."""
    x, y = _px(c, u, v, 0)
    c.line([(x, y), (x, y - 26)], DARK_TIMBER)
    top = round(22 * grown)
    if top <= 0:
        return
    c.draw.rectangle([x - 2, y - top, x + 1, y - 1], fill=(*LEAF, 255))
    c.line([(x + 2, y - top + 1), (x + 2, y - 1)], SHADOW_GREEN)
    c.line([(x - 3, y - top + 2), (x - 3, y - 2)], OUTLINE)
    for k in range(4, top, 4):
        c.dot((x - 1 + (k // 4) % 2, y - k), SUN_GRASS if grown >= 1 else LEAF)
        c.dot((x + 1 - (k // 4) % 2, y - k - 1), PALE_SAND if grown >= 1 else SUN_GRASS)


def _vine(c: Canvas, u: float, v: float, grown: float) -> None:
    """A low trained vine on a stake, grape clusters under its leaves."""
    x, y = _px(c, u, v, 0)
    c.line([(x, y), (x, y - 9)], TIMBER)
    if grown <= 0:
        return
    r = 3 + round(2 * grown)
    c.draw.ellipse([x - r, y - 6 - r, x + r, y - 6 + r // 2], fill=(*LEAF, 255), outline=(*OUTLINE, 255))
    c.draw.ellipse([x - r + 1, y - 6 - r + 1, x, y - 7], fill=(*SUN_GRASS, 255))
    if grown >= 1:
        for dx in (-3, 2):
            c.draw.rectangle([x + dx - 1, y - 6, x + dx + 1, y - 4], fill=(*TERRACOTTA, 255))
            c.dot((x + dx, y - 3), SLATE)
            c.dot((x + dx - 1, y - 6), SUN_TERRACOTTA)


def _tea_bush(c: Canvas, u: float, v: float, grown: float) -> None:
    """A clipped, rounded tea bush; touching bushes read as hedge rows."""
    x, y = _px(c, u, v, 0)
    if grown <= 0:
        c.dot((x, y - 1), LEAF)
        return
    r = 3 + round(3 * grown)
    h = 2 + round(4 * grown)
    c.draw.ellipse([x - r, y - h - 3, x + r, y + 1], fill=(*SHADOW_GREEN, 255), outline=(*OUTLINE, 255))
    c.draw.ellipse([x - r + 1, y - h - 3, x + r - 2, y - 2], fill=(*LEAF, 255))
    c.line([(x - r + 2, y - h - 2), (x + r - 3, y - h - 2)], SUN_GRASS)


def _coffee_shrub(c: Canvas, u: float, v: float, grown: float) -> None:
    """A dark, glossy coffee shrub studded with red cherries."""
    x, y = _px(c, u, v, 0)
    c.line([(x, y), (x, y - 4)], DARK_TIMBER)
    if grown <= 0:
        return
    r = 2 + round(3 * grown)
    h = 6 + round(8 * grown)
    c.draw.ellipse([x - r, y - h, x + r, y - 2], fill=(*SHADOW_GREEN, 255), outline=(*OUTLINE, 255))
    c.draw.ellipse([x - r + 1, y - h + 1, x, y - 4], fill=(*LEAF, 255))
    if grown >= 1:
        for dx, dy in ((-2, 5), (2, 7), (0, 9), (3, 4), (-3, 9)):
            c.dot((x + dx, y - dy), SUN_TERRACOTTA)


def _plant_grid(c: Canvas, plant: Plant, stage: str, us: list[float], vs: list[float]) -> None:
    """Plants at every (u, v) of the grid, drawn back to front."""
    if stage == "pad":
        return
    for u, v in sorted(((u, v) for u in us for v in vs), key=lambda p: (p[0] + p[1], p[0])):
        plant(c, u, v, GROWTH[stage])


def _garden(stage: str, s: Style, extra: int = 44) -> Canvas:
    """Yard, plot and the small shed on the plot's back edge."""
    c = Canvas(2, 2, extra)
    yard(c)
    _garden_plot(c, stage)
    draw_block(c, _style_block(s, 0.25, 0.1, 1.2, 0.6, 11, 9), stage)
    if stage in ("walls", "done"):
        style_door(c, s, 0.6, 0.6, height=7)
    return c


_GARDEN_ROWS = [0.95, 1.4, 1.85]


def _hop_garden(stage: str) -> Image.Image:
    c = _garden(stage, NORTHERN_EUROPEAN, 48)
    if stage == "done":
        for i in range(3):
            bale(c, 1.45 + i * 0.15, 0.4)
    us = [0.25, 0.65, 1.05, 1.45, 1.85]
    if stage != "pad":
        for v in _GARDEN_ROWS:
            # Overhead wires the bines climb to.
            c.line([c.p(us[0], v, 26), c.p(us[-1], v, 26)], DARK_TIMBER)
    _plant_grid(c, _hop_bine, stage, us, _GARDEN_ROWS)
    return c.img


def _vineyard(stage: str) -> Image.Image:
    c = _garden(stage, MEDITERRANEAN)
    _plant_grid(c, _vine, stage, [0.2 + 0.18 * i for i in range(10)], _GARDEN_ROWS)
    if stage == "done":
        cypress(c, 1.55, 0.35)
        amphora(c, 1.3, 0.75)
        amphora(c, 1.45, 0.68)
    return c.img


def _tea_garden(stage: str) -> Image.Image:
    c = _garden(stage, EAST_ASIAN)
    _plant_grid(c, _tea_bush, stage, [0.2 + 0.16 * i for i in range(11)], _GARDEN_ROWS)
    if stage == "done":
        # A stone lantern by the shed and a basket of picked leaves.
        stone_lantern(c, 1.5, 0.35, height=10, cap=0.04)
        bale(c, 1.8, 0.55)
    return c.img


def _coffee_grove(stage: str) -> Image.Image:
    c = _garden(stage, MIDDLE_EASTERN, 48)
    if stage == "done":
        palm(c, 1.6, 0.3, 26)
    _plant_grid(c, _coffee_shrub, stage, [0.3, 0.7, 1.1, 1.5, 1.85], _GARDEN_ROWS)
    if stage == "done":
        sack(c, 1.4, 0.7)
    return c.img


def _brewery(stage: str) -> Image.Image:
    s = NORTHERN_EUROPEAN
    c = Canvas(2, 2, 60)
    yard(c)
    b = _style_block(s, 0.2, 0.25, 1.45, 1.4, 18, 14)
    draw_block(c, b, stage)
    if stage in ("walls", "done"):
        style_door(c, s, 0.55, 1.4, height=9)
        style_window(c, s, 1.0, 1.4, 13)
        style_window(c, s, 1.3, 1.4, 13)
        style_window(c, s, 1.45, 0.8, 12, lit=False)
    if stage == "done":
        chimney(c, 1.05, 0.4, 18, 42)
        # Casks stacked by the door: three on the ground, one on top.
        for u, v in ((1.55, 1.85), (1.75, 1.7), (1.95, 1.55)):
            barrel(c, u, v)
        barrel(c, 1.75, 1.7, 6)
        # Hanging sign with a golden tankard.
        x, y = _px(c, 0.3, 1.4, 14)
        c.line([(x, y), (x - 5, y + 2)], DARK_TIMBER)
        c.draw.rectangle([x - 8, y + 2, x - 3, y + 7], fill=(*WHEAT, 255), outline=(*OUTLINE, 255))
        c.dot((x - 5, y + 4), DARK_TIMBER)
    return c.img


def _wine_press(c: Canvas, u: float, v: float) -> None:
    """A basket press: slatted tub, screw post and a turning bar."""
    box(c, u - 0.15, v - 0.15, u + 0.15, v + 0.15, 7, TIMBER_WALL)
    flat_top(c, u - 0.15, v - 0.15, u + 0.15, v + 0.15, 7, TERRACOTTA)
    for k in (-0.08, 0.02, 0.12):
        c.line([c.p(u + k, v + 0.15, 0), c.p(u + k, v + 0.15, 7)], DARK_TIMBER)
    x, y = _px(c, u, v, 7)
    c.line([(x, y), (x, y - 12)], DARK_TIMBER, width=2)
    c.line([(x - 6, y - 9), (x + 6, y - 7)], TIMBER, width=2)
    c.line([(x - 6, y - 9), (x + 6, y - 7)], OUTLINE)


def _winery(stage: str) -> Image.Image:
    s = MEDITERRANEAN
    c = Canvas(2, 2, 52)
    yard(c)
    if stage == "done":
        cypress(c, 1.7, 0.15, 30)
    b = _style_block(s, 0.2, 0.3, 1.45, 1.4, 20, 16)
    draw_block(c, b, stage)
    if stage in ("walls", "done"):
        _cornice(c, b.u0, b.v0, b.u1, b.v1, 3, LIGHT_STONE)
        x, y = _px(c, 0.7, 1.4, 0)
        arch(c, x, y - 1, 7, 11, DARK_TIMBER)
        style_window(c, s, 1.15, 1.4, 15)
        style_window(c, s, 0.35, 1.4, 15)
        style_window(c, s, 1.45, 0.85, 14, lit=False)
    if stage == "done":
        _wine_press(c, 1.7, 1.55)
        barrel(c, 0.35, 1.75)
        barrel(c, 0.6, 1.85)
        amphora(c, 1.25, 1.8)
        amphora(c, 1.4, 1.9)
    return c.img


def _kettle(c: Canvas, u: float, v: float, z: float) -> None:
    """An iron kettle on a small brazier, steam curling off its spout."""
    x, y = _px(c, u, v, z)
    c.draw.rectangle([x - 3, y - 3, x + 3, y], fill=(*SHADOW_STONE, 255), outline=(*OUTLINE, 255))
    c.dot((x, y - 1), SUN_TERRACOTTA)
    c.draw.ellipse([x - 3, y - 8, x + 3, y - 3], fill=(*SLATE, 255), outline=(*OUTLINE, 255))
    c.line([(x + 3, y - 6), (x + 5, y - 8)], OUTLINE)
    for dx, dy in ((5, 10), (6, 12), (5, 14)):
        c.dot((x + dx, y - dy), CREAM)


def _tea_house(stage: str) -> Image.Image:
    s = EAST_ASIAN
    c = Canvas(2, 2, 56)
    yard(c)
    plinth = (0.15, 0.25, 1.75, 1.75)
    if stage == "pad":
        pad(c, *plinth)
        return c.img
    box(c, *plinth, 4, STONE_WALL)
    flat_top(c, *plinth, 4, PINE)
    u0, v0, u1, v1 = 0.3, 0.4, 1.35, 1.25
    if stage == "frame":
        frame_posts(c, u0, v0, u1, v1, 22)
        return c.img
    shadow(c, u0, v0, u1, v1)
    _storey(c, s, u0, v0, u1, v1, 4, 20)
    style_door(c, s, 0.75, v1, height=10, z0=4)
    style_window(c, s, 1.1, v1, 14)
    style_window(c, s, u1, 0.8, 13, lit=False)
    if stage == "walls":
        flat_top(c, u0, v0, u1, v1, 20, DARK_TIMBER)
        scaffold(c, u0, v0, u1, v1, 20)
        return c.img
    # Red lacquered veranda posts carry the wide roof out over the deck.
    for u, v in ((0.2, 1.65), (1.0, 1.65), (1.65, 1.65), (1.65, 1.1), (1.65, 0.55)):
        c.line([c.p(u, v, 4), c.p(u, v, 20)], s.accent, width=2)
    _kettle(c, 1.35, 1.5, 4)
    bale(c, 0.45, 1.55)
    flared_roof(c, 0.2, 0.55, 1.65, 1.65, 20, 10, s.roof, overhang=0.12, lift=5, finial=True)
    # Red paper lanterns under the eaves.
    for u, v in ((0.55, 1.75), (1.4, 1.75)):
        x, y = _px(c, u, v, 17)
        c.draw.rectangle([x - 1, y, x + 1, y + 3], fill=(*SUN_TERRACOTTA, 255), outline=(*OUTLINE, 255))
        c.dot((x, y + 1), WHEAT)
    return c.img


def _roasting_drum(c: Canvas, u: float, v: float) -> None:
    """A brick firebox carrying an iron drum, with a hand crank."""
    box(c, u - 0.2, v - 0.15, u + 0.2, v + 0.15, 6, BRICK)
    flat_top(c, u - 0.2, v - 0.15, u + 0.2, v + 0.15, 6, TERRACOTTA)
    x, y = _px(c, u, v + 0.15, 0)
    c.draw.rectangle([x - 2, y - 4, x + 2, y - 1], fill=(*OUTLINE, 255))
    c.dot((x, y - 2), WHEAT)
    c.dot((x - 1, y - 2), SUN_TERRACOTTA)
    x, y = _px(c, u, v, 6)
    c.draw.ellipse([x - 7, y - 9, x + 7, y], fill=(*SHADOW_STONE, 255), outline=(*OUTLINE, 255))
    c.draw.ellipse([x - 6, y - 8, x + 1, y - 4], fill=(*STONE, 255))
    c.line([(x - 7, y - 4), (x + 7, y - 4)], SLATE)
    c.line([(x + 7, y - 5), (x + 10, y - 7), (x + 10, y - 10)], DARK_TIMBER)


def _roastery(stage: str) -> Image.Image:
    s = MIDDLE_EASTERN
    c = Canvas(2, 2, 52)
    yard(c)
    b = _style_block(s, 0.2, 0.25, 1.45, 1.35, 20, 0)
    draw_block(c, b, stage)
    if stage in ("walls", "done"):
        style_door(c, s, 0.55, b.v1, height=10)
        style_window(c, s, 1.15, b.v1, 15)
        style_window(c, s, b.u1, 0.8, 15, lit=False)
    if stage == "done":
        awning(c, 0.85, 1.4, b.v1, 12, depth=0.3)
        dome(c, 0.8, 0.8, 23, 12, 4, s.dome, s.wall, band=s.accent)
        palm(c, 1.85, 0.3, 24)
        _roasting_drum(c, 1.1, 1.7)
        for u, v in ((0.35, 1.6), (0.5, 1.8), (1.75, 1.45), (1.85, 1.65)):
            sack(c, u, v)
    return c.img


_LUXURY_DRAWERS: dict[str, Callable[[str], Image.Image]] = {
    "hop-garden": _hop_garden, "brewery": _brewery, "vineyard": _vineyard, "winery": _winery,
    "tea-garden": _tea_garden, "tea-house": _tea_house, "coffee-grove": _coffee_grove, "roastery": _roastery,
}


# Age signatures (`add-age-signatures` D11) ----------------------------
#
# One signature building per age, in the base style with the age's
# materials. Each drawer takes the construction stage and an operational
# frame: None is the idle sprite, 0 and 1 the two operational frames.
# Frames only move a small detail (flame, sign, banner, beam, glow) on
# the idle canvas.

def _cylinder(c: Canvas, u: float, v: float, z0: float, z1: float, half: int, mat: Material,
              band: Rgb | None = None) -> None:
    """A round stack: lit left half, shaded right half, outlined right
    edge and a darker cap ring."""
    x, y0 = _px(c, u, v, z0)
    _, y1 = _px(c, u, v, z1)
    c.draw.rectangle([x - half, y1, x - 1, y0], fill=(*mat.lit, 255))
    c.draw.rectangle([x, y1, x + half - 1, y0], fill=(*mat.shade, 255))
    c.draw.line([(x + half, y1), (x + half, y0)], fill=(*OUTLINE, 255))
    if band is not None:
        c.draw.rectangle([x - half, y1 + 3, x + half - 1, y1 + 5], fill=(*band, 255))
    c.draw.rectangle([x - half - 1, y1 - 1, x + half, y1 + 1], fill=(*SHADOW_STONE, 255))
    c.draw.line([(x - half, y1 - 1), (x + half - 1, y1 - 1)], fill=(*OUTLINE, 255))


def _walls_stage(c: Canvas, u0: float, v0: float, u1: float, v1: float, z: float) -> Image.Image:
    """Finish the walls construction stage: open top and scaffolding."""
    flat_top(c, u0, v0, u1, v1, z, DARK_TIMBER)
    scaffold(c, u0, v0, u1, v1, z)
    return c.img


def _puff(c: Canvas, x: int, y: int, radius: int) -> None:
    """A round smoke puff, lit from the upper left."""
    for dy in range(-radius, radius + 1):
        for dx in range(-radius, radius + 1):
            if dx * dx + dy * dy > radius * radius:
                continue
            fill = CREAM if dx + dy < 0 else (STONE if dx + dy > radius // 2 else LIGHT_STONE)
            c.dot((x + dx, y + dy), fill)


# Monument (Antiquity) ---------------------------------------------------

def _podium(c: Canvas, steps: int = 3) -> None:
    for i in range(steps):
        d = 0.15 + i * 0.15
        box(c, d, d, 3 - d, 3 - d, (i + 1) * 3, STONE_WALL, z0=i * 3)
        flat_top(c, d, d, 3 - d, 3 - d, (i + 1) * 3, LIGHT_STONE)


def _brazier(c: Canvas, u: float, v: float, z: float, frame: int | None) -> None:
    """A bronze bowl on a tripod; lit, its flame flickers between frames."""
    x, y = _px(c, u, v, z)
    for dx in (-3, 0, 3):
        c.line([(x + dx, y), (x, y - 6)], DARK_TIMBER)
    c.draw.ellipse([x - 4, y - 9, x + 4, y - 5], fill=(*THATCH, 255), outline=(*OUTLINE, 255))
    c.line([(x - 3, y - 8), (x + 2, y - 8)], WHEAT)
    if frame is None:
        c.dot((x - 1, y - 9), SHADOW_STONE)
        c.dot((x + 1, y - 9), SHADOW_STONE)
        return
    lean = 1 if frame == 0 else -1
    flame = [((0, -10), SUN_TERRACOTTA), ((-2, -10), SUN_TERRACOTTA), ((2, -10), SUN_TERRACOTTA),
             ((-1, -11), WHEAT), ((1, -11), SUN_TERRACOTTA), ((0, -12), WHEAT), ((lean, -13), CREAM),
             ((lean, -14), WHEAT), ((-lean, -12), WHEAT), ((lean * 2, -15), SUN_TERRACOTTA)]
    if frame == 1:
        flame += [((0, -15), WHEAT), ((-1, -16), SUN_TERRACOTTA)]
    for (dx, dy), fill in flame:
        c.dot((x + dx, y + dy), fill)


def _monument(stage: str, frame: int | None = None) -> Image.Image:
    """A stepped stone podium carrying a temple front of six columns
    under a pediment, a bronze brazier on the steps. Construction shows
    the project: podium, columns in scaffolding, roofless colonnade."""
    c = Canvas(3, 3, 76)
    yard(c)
    _podium(c, 1 if stage == "pad" else 3)
    if stage == "pad":
        return c.img
    base = 9
    u0, v0, u1, v1, front = 0.85, 0.75, 2.25, 1.55, 2.15
    top = base + 20 if stage != "frame" else base + 12
    shadow(c, u0, v0, u1, v1)
    box(c, u0, v0, u1, v1, top, TRAVERTINE, z0=base)
    _face(c, "lit", u0, u1, v1, base, top, SHADOW_STONE)
    x, y = _px(c, (u0 + u1) / 2, v1, base)
    arch(c, x, y - 1, 5, 11 if stage != "frame" else 8, OUTLINE)
    if stage == "frame":
        flat_top(c, u0, v0, u1, v1, top, SHADOW_STONE)
        _columns(c, u0 + 0.06, u1 - 0.06, front, base, base + 20, 6)
        scaffold(c, u0, v0, u1, front, base + 18)
        return c.img
    _columns(c, u1 - 0.05, u1 - 0.05, 1.85, base, top, 1)
    _columns(c, u0 + 0.06, u1 - 0.06, front, base, top, 6)
    box(c, u0, v1, u1, front + 0.05, top + 3, TRAVERTINE, z0=top)
    _face_line(c, "lit", u0, u1, front + 0.05, top + 1, LIGHT_STONE)
    if stage == "walls":
        flat_top(c, u0, v0, u1, v1, top, SHADOW_STONE)
        flat_top(c, u0, v1, u1, front + 0.05, top + 3, LIGHT_STONE)
        return c.img
    gable_roof(c, u0, v0 - 0.05, u1, front + 0.05, top + 3, 11, TILE_ROOF, TRAVERTINE, axis="v", overhang=0.06)
    x, y = _px(c, (u0 + u1) / 2, front + 0.05, top + 7)
    c.draw.ellipse([x - 2, y - 2, x + 2, y + 1], fill=(*LIGHT_STONE, 255), outline=(*STONE, 255))
    _brazier(c, 0.62, 2.35, base, frame)
    return c.img


# Guild hall (Medieval) -----------------------------------------------------

def _guild_sign(c: Canvas, u: float, v: float, z: float, frame: int | None) -> None:
    """An iron arm out of the wall with a hanging board; the board swings
    between the operational frames."""
    ax, ay = _px(c, u, v, z)
    bx, by = _px(c, u, v + 0.45, z)
    c.line([(ax, ay), (bx, by)], OUTLINE)
    c.line([(ax, ay + 3), (bx - 4, by - 1)], OUTLINE)
    swing = {None: 0, 0: -2, 1: 2}[frame]
    hx = bx - 3 + swing
    c.line([(bx - 3, by), (hx, by + 3)], OUTLINE)
    c.draw.rectangle([hx - 4, by + 3, hx + 4, by + 11], fill=(*WHEAT, 255), outline=(*OUTLINE, 255))
    # A red key, the guild's mark.
    c.draw.ellipse([hx - 3, by + 5, hx - 1, by + 7], outline=(*FLAG_RED, 255))
    c.draw.line([(hx - 1, by + 6), (hx + 3, by + 6)], fill=(*FLAG_RED, 255))
    c.dot((hx + 2, by + 7), FLAG_RED)


def _guild_hall(stage: str, frame: int | None = None) -> Image.Image:
    """Stone ground floor, two timber-framed storeys, a steep tiled roof
    with a bell turret and a hanging guild sign."""
    c = Canvas(3, 3, 96)
    yard(c)
    u0, v0, u1, v1 = 0.3, 0.45, 2.45, 2.3
    hall = Block(u0, v0, u1, v1, 34, PLASTER, TILE_ROOF, "gable_u", 24, framed=True)
    if stage in ("pad", "frame"):
        draw_block(c, hall, stage)
        return c.img
    shadow(c, u0, v0, u1, v1)
    box(c, u0, v0, u1, v1, 12, STONE_WALL)
    box(c, u0, v0, u1, v1, 34, PLASTER, z0=12)
    timber_frame(c, u0, u1, v1, 12, 23, step=0.3)
    timber_frame(c, u0, u1, v1, 23, 34, step=0.3)
    c.line([c.p(u1, v0, 23), c.p(u1, v1, 23)], TIMBER)
    c.line([c.p(u0, v1, 12), c.p(u1, v1, 12), c.p(u1, v0, 12)], DARK_TIMBER)
    x, y = _px(c, 1.0, v1, 0)
    arch(c, x, y - 1, 5, 10, DARK_TIMBER)
    for u in (0.55, 1.5, 1.9):
        window(c, "left", u, v1, 6)
    for z in (19, 30):
        for u in (0.55, 0.95, 1.35, 1.75, 2.15):
            window(c, "left", u, v1, z)
        for v in (0.8, 1.35, 1.9):
            window(c, "right", u1, v, z, lit=False)
    if stage == "walls":
        return _walls_stage(c, u0, v0, u1, v1, 34)
    gable_roof(c, u0, v0, u1, v1, 34, 24, TILE_ROOF, PLASTER, axis="u", overhang=0.12)
    # Bell turret astride the ridge.
    vm = (v0 + v1) / 2
    box(c, 1.25, vm - 0.14, 1.53, vm + 0.14, 66, TIMBER_WALL, z0=54)
    x, y = _px(c, 1.39, vm + 0.14, 58)
    c.draw.rectangle([x - 1, y - 4, x + 1, y], fill=(*OUTLINE, 255))
    c.dot((x, y - 1), WHEAT)
    hip_roof(c, 1.25, vm - 0.14, 1.53, vm + 0.14, 66, 9, SLATE_ROOF, overhang=0.05)
    _guild_sign(c, 2.25, v1, 16, frame)
    return c.img


# Gallery (Renaissance) ---------------------------------------------------

def _banner(c: Canvas, u: float, v: float, z: float, frame: int | None) -> None:
    """A pole with a long banner: limp when idle, blowing out to the east
    in two shapes while a commission runs."""
    x, y = _px(c, u, v, z)
    c.line([(x, y), (x, y - 22)], DARK_TIMBER)
    c.dot((x, y - 23), WHEAT)
    if frame is None:
        c.draw.rectangle([x + 1, y - 21, x + 3, y - 12], fill=(*FLAG_RED, 255))
        c.draw.line([(x + 2, y - 19), (x + 2, y - 15)], fill=(*WHEAT, 255))
        return
    for i in range(9):
        wave = (i // 3) % 2 if frame == 0 else ((i + 1) // 3) % 2
        top = y - 21 + wave + (i // 4)
        c.draw.line([(x + 1 + i, top), (x + 1 + i, top + 3)], fill=(*FLAG_RED, 255))
        if i % 3 == 1:
            c.dot((x + 1 + i, top + 1), WHEAT)


def _gallery(stage: str, frame: int | None = None) -> Image.Image:
    """A stuccoed palazzo front with an arched loggia, a cornice, a statue
    niche between the upper windows and a banner on the roof."""
    c = Canvas(2, 2, 64)
    yard(c)
    u0, v0, u1, v1 = 0.2, 0.3, 1.75, 1.6
    body = Block(u0, v0, u1, v1, 28, OCHRE_STUCCO, TILE_ROOF, "hip", 7)
    if stage in ("pad", "frame"):
        draw_block(c, body, stage)
        return c.img
    shadow(c, u0, v0, u1, v1)
    box(c, u0, v0, u1, v1, 12, STONE_WALL)
    box(c, u0, v0, u1, v1, 28, OCHRE_STUCCO, z0=12)
    for u in (0.47, 0.97, 1.47):
        x, y = _px(c, u, v1, 0)
        arch(c, x, y - 1, 9, 10, SHADOW_STONE)
        arch(c, x, y - 1, 7, 9, OUTLINE)
    _face_line(c, "lit", u0, u1, v1, 12, LIGHT_STONE)
    _face_line(c, "shaded", v0, v1, u1, 12, LIGHT_STONE)
    for u in (0.45, 1.5):
        x, y = _px(c, u, v1, 18)
        c.draw.rectangle([x - 1, y - 3, x + 1, y + 2], fill=(*DARK_TIMBER, 255))
        c.draw.line([(x - 2, y - 4), (x + 2, y - 4)], fill=(*CREAM, 255))
    x, y = _px(c, 0.97, v1, 15)
    arch(c, x, y, 5, 10, SHADOW_STONE)
    c.draw.rectangle([x - 1, y - 7, x, y], fill=(*CREAM, 255))
    c.dot((x, y - 8), CREAM)
    c.dot((x + 1, y - 5), PALE_SAND)
    for v in (0.65, 1.25):
        x, y = _px(c, u1, v, 18)
        c.draw.rectangle([x - 1, y - 3, x + 1, y + 2], fill=(*OUTLINE, 255))
    if stage == "walls":
        return _walls_stage(c, u0, v0, u1, v1, 28)
    box(c, u0 - 0.05, v0 - 0.05, u1 + 0.05, v1 + 0.05, 31, TRAVERTINE, z0=28)
    hip_roof(c, u0 - 0.05, v0 - 0.05, u1 + 0.05, v1 + 0.05, 31, 7, TILE_ROOF, overhang=0.04)
    _banner(c, 1.6, 0.45, 33, frame)
    return c.img


# Steam engine (Industrial) ---------------------------------------------------

def _beam(c: Canvas, tilt: int) -> None:
    """The rocking beam on a stone bob wall beside the engine house, and
    the pump rod hanging from its outer end."""
    box(c, 1.22, 1.15, 1.4, 1.35, 30, STONE_WALL)
    flat_top(c, 1.22, 1.15, 1.4, 1.35, 30, LIGHT_STONE)
    inner = _px(c, 0.85, 1.25, 32 - tilt)
    outer = _px(c, 1.85, 1.25, 32 + tilt)
    c.line([inner, outer], PINE, width=3)
    c.line([(inner[0], inner[1] + 2), (outer[0], outer[1] + 2)], OUTLINE)
    pivot = _px(c, 1.31, 1.25, 32)
    c.draw.rectangle([pivot[0] - 1, pivot[1] - 1, pivot[0] + 1, pivot[1] + 1], fill=(*OUTLINE, 255))
    c.line([(outer[0], outer[1] + 1), _px(c, 1.85, 1.25, 6)], OUTLINE)


def _coal_heap(c: Canvas, u: float, v: float) -> None:
    """A conical heap of coal."""
    x, y = _px(c, u, v, 0)
    pts = [(x - 9, y), (x - 5, y - 5), (x - 1, y - 8), (x + 3, y - 7), (x + 7, y - 4), (x + 10, y)]
    c.poly(pts, SHADOW_STONE)
    c.poly([(x - 9, y), (x - 5, y - 5), (x - 1, y - 8), (x, y)], SLATE)
    c.line(pts[2:], OUTLINE)
    c.line([(x - 9, y), (x + 10, y)], OUTLINE)
    for dx, dy in ((-4, -3), (1, -5), (4, -3), (-1, -2), (6, -2)):
        c.dot((x + dx, y + dy), STONE)


def _steam_engine(stage: str, frame: int | None = None) -> Image.Image:
    """A brick engine house with a tall round chimney, a rocking beam over
    its end wall and a coal heap."""
    c = Canvas(2, 2, 84)
    yard(c)
    u0, v0, u1, v1 = 0.2, 0.55, 1.15, 1.65
    house = Block(u0, v0, u1, v1, 24, BRICK, SLATE_ROOF, "gable_v", 11)
    if stage == "pad":
        draw_block(c, house, stage)
        return c.img
    box(c, 1.3, 0.25, 1.62, 0.57, 6, STONE_WALL)
    flat_top(c, 1.3, 0.25, 1.62, 0.57, 6, LIGHT_STONE)
    chimney_top = {"frame": 22, "walls": 44, "done": 64}[stage]
    _cylinder(c, 1.46, 0.41, 6, chimney_top, 3, BRICK, band=LIGHT_STONE if stage == "done" else None)
    if stage == "frame":
        draw_block(c, house, stage)
        return c.img
    shadow(c, u0, v0, u1, v1)
    box(c, u0, v0, u1, v1, 24, BRICK)
    _brickwork(c, u0, v0, u1, v1, 0, 24)
    x, y = _px(c, 0.68, v1, 0)
    arch(c, x, y - 1, 5, 16, OUTLINE)
    c.draw.line([(x - 2, y - 9), (x + 2, y - 9)], fill=(*LIGHT_STONE, 255))
    door(c, 0.38, v1, height=8)
    window(c, "right", u1, 0.85, 14, lit=False)
    if stage == "walls":
        return _walls_stage(c, u0, v0, u1, v1, 24)
    gable_roof(c, u0, v0, u1, v1, 24, 11, SLATE_ROOF, BRICK, axis="v")
    # Pump head under the beam's outer end.
    box(c, 1.74, 1.13, 1.96, 1.37, 6, STONE_WALL)
    flat_top(c, 1.74, 1.13, 1.96, 1.37, 6, SHADOW_STONE)
    _beam(c, {None: 0, 0: 6, 1: -6}[frame])
    _coal_heap(c, 1.5, 1.8)
    if frame is not None:
        sx, sy = _px(c, 1.46, 0.41, chimney_top)
        puffs = ((1, 4, 2), (3, 9, 3)) if frame == 0 else ((1, 3, 1), (5, 11, 2))
        for dx, dy, radius in puffs:
            _puff(c, sx + dx, sy - dy, radius)
    return c.img


# Power plant (Modern) ---------------------------------------------------

def _plant_windows(c: Canvas, glow: int | None) -> None:
    """Tall windows on both walls: dark glass when cold, lit in two
    alternating patterns while the plant runs."""
    panes = [("lit", u, 2.6) for u in (0.5, 0.8, 1.1, 1.4, 1.7)] + \
            [("shaded", v, 2.0) for v in (1.05, 1.4, 1.75, 2.1)]
    for i, (face, a, at) in enumerate(panes):
        if glow is None:
            fill = GLASS.lit if face == "lit" else GLASS.shade
        else:
            fill = CREAM if (i + glow) % 2 == 0 else WHEAT
        _face(c, face, a - 0.07, a + 0.07, at, 7, 28, fill)
        _face_line(c, face, a - 0.07, a + 0.07, at, 17, OUTLINE)


def _pylon(c: Canvas, u: float, v: float) -> None:
    """A lattice pylon carrying two insulator arms."""
    x, y = _px(c, u, v, 0)
    top = y - 34
    c.line([(x - 4, y), (x - 1, top)], SHADOW_STONE)
    c.line([(x + 4, y), (x + 1, top)], OUTLINE)
    for k in range(4):
        y0 = y - k * 8
        w0, w1 = 4 - k * 0.75, 4 - (k + 1) * 0.75
        c.line([(round(x - w0), y0), (round(x + w1), y0 - 8)], SHADOW_STONE)
        c.line([(round(x + w0), y0), (round(x - w1), y0 - 8)], SHADOW_STONE)
    for dy, half in ((6, 7), (12, 5)):
        c.line([(x - half, top + dy), (x + half, top + dy)], OUTLINE)
        c.dot((x - half, top + dy + 1), CREAM)
        c.dot((x + half, top + dy + 1), CREAM)


_PLANT_STACKS = ((1.75, 0.3), (2.45, 0.45))


def _power_plant(stage: str, frame: int | None = None) -> Image.Image:
    """A brick and concrete hall with tall windows, two chimneys and a
    transformer yard with a pylon."""
    c = Canvas(3, 3, 100)
    yard(c)
    u0, v0, u1, v1 = 0.3, 0.75, 2.0, 2.6
    hall = Block(u0, v0, u1, v1, 34, BRICK, SLATE_ROOF, "gable_u", 8)
    stack_top = {"pad": 0, "frame": 30, "walls": 60, "done": 84}[stage]
    if stage != "pad":
        for u, v in _PLANT_STACKS:
            _cylinder(c, u, v, 0, stack_top, 4, CONCRETE, band=FLAG_RED if stage == "done" else None)
    if stage in ("pad", "frame"):
        draw_block(c, hall, stage)
        return c.img
    shadow(c, u0, v0, u1, v1)
    box(c, u0, v0, u1, v1, 34, BRICK)
    _brickwork(c, u0, v0, u1, v1, 4, 30)
    box(c, u0, v0, u1, v1, 4, CONCRETE)
    _plant_windows(c, None if stage == "walls" else frame)
    if stage == "walls":
        return _walls_stage(c, u0, v0, u1, v1, 34)
    box(c, u0, v0, u1, v1, 37, CONCRETE, z0=33)
    gable_roof(c, u0, v0, u1, v1, 37, 8, SLATE_ROOF, CONCRETE, axis="u", overhang=0.06)
    # Transformer yard: two transformers behind a fence, and the pylon.
    for u, v in ((2.2, 1.35), (2.2, 1.95)):
        box(c, u, v, u + 0.3, v + 0.35, 9, Material(STONE, SHADOW_STONE))
        flat_top(c, u, v, u + 0.3, v + 0.35, 9, LIGHT_STONE)
        for k in (0.08, 0.22):
            x, y = _px(c, u + k, v + 0.17, 9)
            c.line([(x, y), (x, y - 3)], CREAM)
    c.line([c.p(2.1, 2.45, 4), c.p(2.85, 2.45, 4), c.p(2.85, 1.2, 4)], SHADOW_STONE)
    _pylon(c, 2.65, 2.7)
    if frame is not None:
        for i, (u, v) in enumerate(_PLANT_STACKS):
            x, y = _px(c, u, v, stack_top)
            _puff(c, x + 1, y - (3 if (i + frame) % 2 else 7), 2)
    return c.img


SIGNATURE_DRAWERS: dict[str, Callable[..., Image.Image]] = {
    "monument": _monument, "guild-hall": _guild_hall, "gallery": _gallery,
    "steam-engine": _steam_engine, "power-plant": _power_plant,
}


def draw_signature_frame(kind: str, frame: int) -> Image.Image:
    """Operational frame of an age signature, on the idle sprite's canvas."""
    return _crop_to_idle(SIGNATURE_DRAWERS[kind]("done", frame), SIGNATURE_DRAWERS[kind]("done"))


FOOTPRINTS: dict[str, tuple[int, int]] = {
    "house": (2, 2), "warehouse": (3, 3), "lumberjack-hut": (2, 2), "sawmill": (2, 2),
    "town-center": (3, 3), "bakery": (2, 2), "grain-farm": (2, 2), "windmill": (2, 2), "mine": (2, 2),
    "charcoal-burner": (2, 2), "smelter": (2, 2), "toolsmith": (2, 2), "library": (2, 2), "quern-house": (2, 2),
    **{f"port-{o}": (2, 3) for o in "nesw"}, **{f"shipyard-{o}": (2, 3) for o in "nesw"},
    **{kind: (2, 2) for kind in _LUXURY_DRAWERS},
    "monument": (3, 3), "guild-hall": (3, 3), "gallery": (2, 2), "steam-engine": (2, 2), "power-plant": (3, 3),
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
    "quern-house": _quern_house,
    **{f"port-{o}": (lambda stage, o=o: _port(o, stage)) for o in "nesw"},
    **{f"shipyard-{o}": (lambda stage, o=o: _shipyard(o, stage)) for o in "nesw"},
    **_LUXURY_DRAWERS,
    **SIGNATURE_DRAWERS,
}

OPERATIONAL_FRAMES: dict[str, int] = {
    "lumberjack-hut": 2, "sawmill": 4, "town-center": 2, "bakery": 2, "grain-farm": 2, "windmill": 4,
    "mine": 2, "charcoal-burner": 2, "smelter": 2, "toolsmith": 2, "library": 2,
    "quern-house": 2, **{f"port-{o}": 2 for o in "nesw"}, **{f"shipyard-{o}": 2 for o in "nesw"},
    **{kind: 2 for kind in _LUXURY_DRAWERS},
    **{kind: 2 for kind in SIGNATURE_DRAWERS},
}


# Upgraded house looks, keyed by tier; tier 1 is the plain house.
TIER_HOUSES: dict[int, Callable[..., Image.Image]] = {2: _house_tier2, 3: _house_tier3}


def draw_windmill_frame(frame: int, frames: int) -> Image.Image:
    """Operational windmill frame: the sails turn a quarter turn per cycle."""
    return _crop_to_idle(_windmill("done", math.pi / 4 + frame * (math.pi / 2) / frames), _windmill("done"))


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
    return _crop_to_idle(_DRAWERS[kind](stage), _DRAWERS[kind]("done"))


def _crop_to_idle(img: Image.Image, idle: Image.Image) -> Image.Image:
    """Crop `img` to the finished building's top plus the smoke-plume
    headroom, so every frame and stage shares one canvas and anchor."""
    top = idle.getbbox()[1]
    return img.crop((0, max(0, top - HEADROOM), img.width, img.height))
