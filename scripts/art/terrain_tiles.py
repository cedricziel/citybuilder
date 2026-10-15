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

import functools
import math
import random

import numpy as np

from art import ground

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


@functools.cache
def _pattern(pattern_id: str, texture: str) -> str:
    """A tile-space pattern skewed onto the iso diamond like `px`. Each cell holds 2 x 2 texture
    repeats and starts half a tile early, so cell edges, where the image is clamped rather than
    wrapped, never fall on a tile or its bleed."""
    texels = ground.texture(texture)
    doubled = np.roll(np.tile(texels, (2, 2, 1)), ground.SIZE // 2, axis=(0, 1))
    return (
        f'<pattern id="{pattern_id}" x="-0.5" y="-0.5" width="2" height="2" patternUnits="userSpaceOnUse" '
        f'patternTransform="matrix(32 16 -32 16 32 0)">'
        f'<image width="2" height="2" preserveAspectRatio="none" href="{ground.to_data_uri(doubled)}"/>'
        "</pattern>"
    )


DEFS = """
<filter id="b1" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="0.9"/></filter>
<mask id="tile"><path d="M32,-1 L66,16 L32,33 L-2,16Z" fill="#fff" shape-rendering="crispEdges"/></mask>
"""


def _svg(body: str, patterns: dict[str, str]) -> str:
    defs = "".join(_pattern(pid, texture) for pid, texture in patterns.items())
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="32" viewBox="0 0 64 32">\n'
        f"<defs>{defs}{DEFS}</defs>\n<g mask=\"url(#tile)\">\n{body}\n</g>\n</svg>\n"
    )


FILL = '<rect x="-4" y="-4" width="72" height="40" fill="url(#{})"/>'


def grass_beach(mask: int, season: str = "") -> str:
    outline, curves = region_uv(mask, rng_for("grass-beach", mask))
    fill, edge = _path(outline, True), " ".join(_path(c, False) for c in curves)
    return _svg(
        FILL.format("beach") + "\n"
        f'<path d="{edge}" stroke="#A89E64" stroke-width="3" stroke-opacity="0.7" fill="none" filter="url(#b1)"/>\n'
        f'<path d="{fill}" fill="url(#grass)"/>\n'
        f'<path d="{edge}" stroke="#3E5A22" stroke-width="1.5" stroke-opacity="0.35" fill="none" filter="url(#b1)"/>',
        {"grass": f"grass-{season}" if season else "grass", "beach": "beach"},
    )


def beach_water(mask: int) -> str:
    outline, curves = region_uv(mask, rng_for("beach-water", mask))
    fill, edge = _path(outline, True), " ".join(_path(c, False) for c in curves)
    return _svg(
        FILL.format("water") + "\n"
        f'<path d="{edge}" stroke="#4E968E" stroke-width="5" stroke-opacity="0.55" fill="none" filter="url(#b1)"/>\n'
        f'<path d="{edge}" stroke="#F4F1E4" stroke-width="3" stroke-opacity="0.25" fill="none" filter="url(#b1)"/>\n'
        f'<path d="{fill}" fill="url(#beach)"/>\n'
        f'<clipPath id="land"><path d="{fill}"/></clipPath>\n'
        f'<path d="{edge}" stroke="#8C7A5C" stroke-width="5" stroke-opacity="0.6" fill="none" clip-path="url(#land)" filter="url(#b1)"/>\n'
        f'<path d="{edge}" stroke="#F4F1E4" stroke-width="1.2" stroke-opacity="0.85" fill="none"/>',
        {"water": "water", "beach": "beach"},
    )


def full(texture: str) -> str:
    """A whole tile of one ground texture (`grass`, `grass-autumn-1`, `water-3`, ...)."""
    return _svg(FILL.format("ground"), {"ground": texture})


# Grass changes with the season, so its shore transitions do too (`-t<mask>-<season>`).
SEASONS = ("autumn", "winter")
# Every terrain tile the atlas has today: base tiles, animation frames, seasons and rock variants.
GROUND = ["grass", "grass-0", "grass-1", "grass-autumn", "grass-autumn-0", "grass-autumn-1",
          "grass-winter", "grass-winter-0", "grass-winter-1", "beach", "beach-0", "beach-1",
          "water", "water-0", "water-1", "water-2", "water-3",
          "forest", "forest-autumn", "forest-winter",
          "mountain", "mountain-v1", "mountain-v2", "mountain-v3"]


def sources() -> dict[str, str]:
    """Every terrain sprite this generator can draw, by atlas name."""
    tiles: dict[str, str] = {}
    for mask in range(1, 15):
        tiles[f"terrain-grass-beach-t{mask}"] = grass_beach(mask)
        for season in SEASONS:
            tiles[f"terrain-grass-beach-t{mask}-{season}"] = grass_beach(mask, season)
        tiles[f"terrain-beach-water-t{mask}"] = beach_water(mask)
    for texture in GROUND:
        tiles[f"terrain-{texture}"] = full(texture)
    return tiles
