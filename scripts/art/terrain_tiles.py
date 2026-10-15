"""Corner-mask (Wang) terrain tiles for the 64x32 iso grid, as SVG (design D6).

Each tile has corners N, E, S, W at (u, v) = (0,0), (1,0), (1,1), (0,1); u = +col, v = +row.
Mask bits N=1, E=2, S=4, W=8 mark the corners carrying the pair's upper terrain. The boundary
crosses each tile edge at the edge's midpoint and leaves it perpendicular, so neighbouring tiles
join. Interior wobble is seeded per (pair, mask) and fades to zero at both ends.

Tiles bleed about 1 point past the diamond: exact diamonds leave 1 px stair gaps between neighbours,
and linear filtering would sample transparent texels. Every region therefore extends past the
edge by BLEED, so the bleed shows the right terrain.
"""

from __future__ import annotations

import math
import random

CORNERS = [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)]  # N E S W
MIDS = [(0.5, 0.0), (1.0, 0.5), (0.5, 1.0), (0.0, 0.5)]  # edge i joins corner i and i+1
INWARD = [(0.0, 1.0), (-1.0, 0.0), (0.0, -1.0), (1.0, 0.0)]
BLEED = 0.08  # in u,v: about 2.5 points
PAIRS = ("grass-beach", "beach-water")

Point = tuple[float, float]


def px(u: float, v: float) -> Point:
    return 32 + 32 * u - 32 * v, 16 * u + 16 * v


def rng_for(pair: str, mask: int) -> random.Random:
    return random.Random(f"{pair}{mask}")


def curve(edge_out: int, edge_in: int, rng: random.Random, steps: int = 20) -> list[Point]:
    """From the midpoint of edge_out, through the tile, to the midpoint of edge_in; bleed points on both ends."""
    m0, m1 = MIDS[edge_out], MIDS[edge_in]
    adjacent = (edge_in - edge_out) % 4 in (1, 3)
    k = 0.3 if adjacent else 0.36
    c0 = (m0[0] + INWARD[edge_out][0] * k, m0[1] + INWARD[edge_out][1] * k)
    c1 = (m1[0] + INWARD[edge_in][0] * k, m1[1] + INWARD[edge_in][1] * k)
    amp, freq, phase = rng.uniform(0.02, 0.05), rng.choice([1, 2]), rng.uniform(0, math.tau)
    points = []
    for i in range(steps + 1):
        t = i / steps
        a, b, c, d = (1 - t) ** 3, 3 * (1 - t) ** 2 * t, 3 * (1 - t) * t**2, t**3
        u = a * m0[0] + b * c0[0] + c * c1[0] + d * m1[0]
        v = a * m0[1] + b * c0[1] + c * c1[1] + d * m1[1]
        du = 3 * ((1 - t) ** 2 * (c0[0] - m0[0]) + 2 * (1 - t) * t * (c1[0] - c0[0]) + t**2 * (m1[0] - c1[0]))
        dv = 3 * ((1 - t) ** 2 * (c0[1] - m0[1]) + 2 * (1 - t) * t * (c1[1] - c0[1]) + t**2 * (m1[1] - c1[1]))
        norm = math.hypot(du, dv) or 1
        w = amp * math.sin(math.pi * t) ** 2 * math.sin(freq * math.tau * t + phase)
        points.append((u - dv / norm * w, v + du / norm * w))
    out0, out1 = INWARD[edge_out], INWARD[edge_in]
    return (
        [(m0[0] - out0[0] * BLEED, m0[1] - out0[1] * BLEED)]
        + points
        + [(m1[0] - out1[0] * BLEED, m1[1] - out1[1] * BLEED)]
    )


def region_uv(mask: int, rng: random.Random) -> tuple[list[Point], list[list[Point]]]:
    """Outline of the upper terrain and its interior boundary curves, in (u, v)."""
    upper = [bool(mask >> i & 1) for i in range(4)]
    outline: list[Point] = []
    curves: list[list[Point]] = []
    i = upper.index(True)
    for _ in range(4):
        if upper[i]:
            cu, cv = CORNERS[i]
            outline.append((cu + (cu - 0.5) * 2 * BLEED, cv + (cv - 0.5) * 2 * BLEED))
        nxt = (i + 1) % 4
        if upper[i] and not upper[nxt]:
            j = nxt  # walk on to where the perimeter re-enters the upper terrain
            while not upper[(j + 1) % 4]:
                j = (j + 1) % 4
            points = curve(i, j, rng)
            outline.extend(points)
            curves.append(points)
        i = nxt
    return outline, curves


def _path(points: list[Point], close: bool) -> str:
    body = " ".join(f"{x:.2f},{y:.2f}" for x, y in (px(u, v) for u, v in points))
    return f"M{body}{'Z' if close else ''}"


PATTERNS = """
<pattern id="grass" width="32" height="16" patternUnits="userSpaceOnUse">
  <rect width="32" height="16" fill="#83A03F"/>
  <rect x="0" y="8" width="32" height="8" fill="#7E9A3C"/>
  <path d="M3,3 l2,-2 l1,2 M19,5 l2,-2 l1,2 M11,11 l2,-2 l1,2 M27,13 l2,-2 l1,2 M7,14 l1,-2 l1,2 M23,9 l1,-2 l1,2" stroke="#A6B852" stroke-width="1" fill="none"/>
  <path d="M8,6 l1,-1 M24,2 l1,-1 M16,14 l1,-1 M30,9 l1,-1 M14,3 l1,-1" stroke="#5C7A2E" stroke-width="1"/>
</pattern>
<pattern id="beach" width="32" height="16" patternUnits="userSpaceOnUse">
  <rect width="32" height="16" fill="#D8BC86"/>
  <path d="M5,4 h1 M21,6 h1 M13,12 h1 M29,14 h1 M9,9 h1 M25,1 h1 M2,13 h1 M17,2 h1" stroke="#B89A66" stroke-width="1"/>
  <path d="M11,6 h1 M27,10 h1" stroke="#EAD3A2" stroke-width="1"/>
</pattern>
<pattern id="water" width="32" height="16" patternUnits="userSpaceOnUse">
  <rect width="32" height="16" fill="#2E6C84"/>
  <path d="M3,4 h6 M19,12 h5 M12,8 h3" stroke="#4E8C9E" stroke-width="1"/>
</pattern>
<filter id="b1" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="0.9"/></filter>
<mask id="tile"><path d="M32,-1 L66,16 L32,33 L-2,16Z" fill="#fff" shape-rendering="crispEdges"/></mask>
"""


def _svg(body: str) -> str:
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="32" viewBox="0 0 64 32">\n'
        f'<defs>{PATTERNS}</defs>\n<g mask="url(#tile)">\n{body}\n</g>\n</svg>\n'
    )


def grass_beach(mask: int) -> str:
    outline, curves = region_uv(mask, rng_for("grass-beach", mask))
    fill, edge = _path(outline, True), " ".join(_path(c, False) for c in curves)
    return _svg(
        '<rect x="-4" y="-4" width="72" height="40" fill="url(#beach)"/>\n'
        f'<path d="{edge}" stroke="#B0A55A" stroke-width="5" fill="none" filter="url(#b1)"/>\n'
        f'<path d="{fill}" fill="url(#grass)"/>\n'
        f'<path d="{edge}" stroke="#5E7A2E" stroke-width="1" stroke-dasharray="1 2" fill="none"/>'
    )


def beach_water(mask: int) -> str:
    outline, curves = region_uv(mask, rng_for("beach-water", mask))
    fill, edge = _path(outline, True), " ".join(_path(c, False) for c in curves)
    return _svg(
        '<rect x="-4" y="-4" width="72" height="40" fill="url(#water)"/>\n'
        f'<path d="{edge}" stroke="#4E968E" stroke-width="12" fill="none" filter="url(#b1)"/>\n'
        f'<path d="{edge}" stroke="#F4F1E4" stroke-width="6" stroke-opacity="0.22" fill="none" filter="url(#b1)"/>\n'
        f'<path d="{fill}" fill="url(#beach)"/>\n'
        f'<clipPath id="land"><path d="{fill}"/></clipPath>\n'
        f'<path d="{edge}" stroke="#A88A5E" stroke-width="5" fill="none" clip-path="url(#land)"/>\n'
        f'<path d="{edge}" stroke="#F4F1E4" stroke-width="1.4" fill="none"/>'
    )


def full(terrain: str, variant: int) -> str:
    rng = random.Random(f"{terrain}{variant}")
    clutter = []
    for _ in range(4 if terrain != "water" else 2):
        x, y = px(rng.uniform(0.2, 0.8), rng.uniform(0.2, 0.8))  # clear of the edges
        if terrain == "grass":
            clutter.append(
                f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="3.5" ry="1.6" fill="#6C8A34"/>'
                f'<circle cx="{x + 1:.1f}" cy="{y - 0.5:.1f}" r="0.7" fill="#E8D7A0"/>'
            )
        elif terrain == "beach":
            clutter.append(f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="1.4" ry="0.8" fill="#9A8B74"/>')
        else:
            clutter.append(f'<path d="M{x - 3:.1f},{y:.1f} h6" stroke="#6FA7B4" stroke-width="1"/>')
    return _svg(f'<rect x="-4" y="-4" width="72" height="40" fill="url(#{terrain})"/>\n' + "\n".join(clutter))


def sources() -> dict[str, str]:
    """Every terrain sprite this generator can draw, by atlas name."""
    tiles: dict[str, str] = {}
    for mask in range(1, 15):
        tiles[f"terrain-grass-beach-t{mask}"] = grass_beach(mask)
        tiles[f"terrain-beach-water-t{mask}"] = beach_water(mask)
    for terrain in ("grass", "beach", "water"):
        for variant in range(3):
            tiles[f"terrain-{terrain}" + (f"-v{variant}" if variant else "")] = full(terrain, variant)
    return tiles
