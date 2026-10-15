"""Corner-based (Wang) terrain transition tiles for the 64x32 iso grid, as SVG.

usage: python3 -I transitions.py <out-dir>

Each tile has four corners N, E, S, W (u,v = (0,0), (1,0), (1,1), (0,1); u = +col, v = +row).
A 4-bit mask says which corners carry the "upper" terrain (grass over sand, sand over water).
The boundary always crosses a tile edge at its midpoint, leaving perpendicular to the edge,
so neighbouring tiles join without seams. Interior wobble is seeded per mask and fades to
zero at the edge midpoints.

Writes <pair>-<mask:02d>.svg for masks 1..14, plus full tiles <terrain>-v<k>.svg.
"""
import math
import os
import random
import sys

CORNERS = [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)]  # N E S W, bits 1 2 4 8
# Edge i joins corner i and i+1. Midpoint and inward normal in (u, v).
MIDS = [(0.5, 0.0), (1.0, 0.5), (0.5, 1.0), (0.0, 0.5)]
INWARD = [(0.0, 1.0), (-1.0, 0.0), (0.0, -1.0), (1.0, 0.0)]

# The tile mask bleeds ~1 px past the exact diamond: exact diamonds leave 1 px stair gaps between
# neighbours. Neighbours paint identical content in the overlap, so it never shows, as long as
# every region also extends past the tile edge by BLEED (in u,v; 0.08 = about 2.5 px).
BLEED = 0.08


def px(u, v):
    return 32 + 32 * u - 32 * v, 16 * u + 16 * v


def curve(edge_out, edge_in, rng, steps=20):
    """Points from the midpoint of edge_out to the midpoint of edge_in, through the tile."""
    m0, m1 = MIDS[edge_out], MIDS[edge_in]
    adjacent = (edge_in - edge_out) % 4 in (1, 3)
    k = 0.3 if adjacent else 0.36
    c0 = (m0[0] + INWARD[edge_out][0] * k, m0[1] + INWARD[edge_out][1] * k)
    c1 = (m1[0] + INWARD[edge_in][0] * k, m1[1] + INWARD[edge_in][1] * k)
    amp, freq, phase = rng.uniform(0.02, 0.05), rng.choice([1, 2]), rng.uniform(0, math.tau)
    pts = []
    for i in range(steps + 1):
        t = i / steps
        a, b, c, d = (1 - t) ** 3, 3 * (1 - t) ** 2 * t, 3 * (1 - t) * t ** 2, t ** 3
        u = a * m0[0] + b * c0[0] + c * c1[0] + d * m1[0]
        v = a * m0[1] + b * c0[1] + c * c1[1] + d * m1[1]
        # tangent for a perpendicular wobble that vanishes at both ends
        du = 3 * ((1 - t) ** 2 * (c0[0] - m0[0]) + 2 * (1 - t) * t * (c1[0] - c0[0]) + t ** 2 * (m1[0] - c1[0]))
        dv = 3 * ((1 - t) ** 2 * (c0[1] - m0[1]) + 2 * (1 - t) * t * (c1[1] - c0[1]) + t ** 2 * (m1[1] - c1[1]))
        norm = math.hypot(du, dv) or 1
        w = amp * math.sin(math.pi * t) ** 2 * math.sin(freq * math.tau * t + phase)
        pts.append((u - dv / norm * w, v + du / norm * w))
    # run a little past both edges so the 1 px bleed shows the right terrain
    out0, out1 = INWARD[edge_out], INWARD[edge_in]
    return [(m0[0] - out0[0] * BLEED, m0[1] - out0[1] * BLEED)] + pts + [(m1[0] - out1[0] * BLEED, m1[1] - out1[1] * BLEED)]


def region(mask, rng):
    """Closed region of the upper terrain and its interior boundary curves (pixel coords)."""
    upper = [bool(mask >> i & 1) for i in range(4)]
    start = upper.index(True)
    outline, curves = [], []
    i = start
    for _ in range(4):
        if upper[i]:
            cu, cv = CORNERS[i]
            outline.append((cu + (cu - 0.5) * 2 * BLEED, cv + (cv - 0.5) * 2 * BLEED))
        nxt = (i + 1) % 4
        if upper[i] and not upper[nxt]:
            j = nxt  # find where the perimeter re-enters the upper terrain
            while not upper[(j + 1) % 4]:
                j = (j + 1) % 4
            pts = curve(i, j, rng)
            outline.extend(pts)
            curves.append(pts)
        i = nxt
    # the walk above may append past the start; trimming is not needed for a closed fill
    fmt = lambda pts: " ".join(f"{x:.2f},{y:.2f}" for x, y in (px(u, v) for u, v in pts))
    return f"M{fmt(outline)}Z", [f"M{fmt(c)}" for c in curves]


PATTERNS = """
<pattern id="grass" width="32" height="16" patternUnits="userSpaceOnUse">
  <rect width="32" height="16" fill="#83A03F"/>
  <rect x="0" y="8" width="32" height="8" fill="#7E9A3C"/>
  <path d="M3,3 l2,-2 l1,2 M19,5 l2,-2 l1,2 M11,11 l2,-2 l1,2 M27,13 l2,-2 l1,2 M7,14 l1,-2 l1,2 M23,9 l1,-2 l1,2" stroke="#A6B852" stroke-width="1" fill="none"/>
  <path d="M8,6 l1,-1 M24,2 l1,-1 M16,14 l1,-1 M30,9 l1,-1 M14,3 l1,-1" stroke="#5C7A2E" stroke-width="1"/>
</pattern>
<pattern id="sand" width="32" height="16" patternUnits="userSpaceOnUse">
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


def svg(body):
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="32" viewBox="0 0 64 32">\n'
        f"<defs>{PATTERNS}</defs>\n<g mask=\"url(#tile)\">\n{body}\n</g>\n</svg>\n"
    )


def grass_sand(mask, rng):
    fill, curves = region(mask, rng)
    edge = " ".join(curves)
    return svg(
        f'<rect width="64" height="32" fill="url(#sand)"/>\n'
        f'<path d="{edge}" stroke="#B0A55A" stroke-width="5" fill="none" filter="url(#b1)"/>\n'
        f'<path d="{fill}" fill="url(#grass)"/>\n'
        f'<path d="{edge}" stroke="#5E7A2E" stroke-width="1" stroke-dasharray="1 2" fill="none"/>'
    )


def sand_water(mask, rng):
    fill, curves = region(mask, rng)
    edge = " ".join(curves)
    return svg(
        f'<rect width="64" height="32" fill="url(#water)"/>\n'
        f'<path d="{edge}" stroke="#4E968E" stroke-width="12" fill="none" filter="url(#b1)"/>\n'
        f'<path d="{edge}" stroke="#F4F1E4" stroke-width="6" stroke-opacity="0.22" fill="none" filter="url(#b1)"/>\n'
        f'<path d="{fill}" fill="url(#sand)"/>\n'
        f'<clipPath id="land"><path d="{fill}"/></clipPath>\n'
        f'<path d="{edge}" stroke="#A88A5E" stroke-width="5" fill="none" clip-path="url(#land)"/>\n'
        f'<path d="{edge}" stroke="#F4F1E4" stroke-width="1.4" fill="none"/>'
    )


def full(terrain, variant):
    rng = random.Random(f"{terrain}{variant}")
    clutter = []
    for _ in range(4 if terrain != "water" else 2):
        u, v = rng.uniform(0.2, 0.8), rng.uniform(0.2, 0.8)  # stay clear of the edges
        x, y = px(u, v)
        if terrain == "grass":
            clutter.append(f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="3.5" ry="1.6" fill="#6C8A34"/>'
                           f'<circle cx="{x + 1:.1f}" cy="{y - 0.5:.1f}" r="0.7" fill="#E8D7A0"/>')
        elif terrain == "sand":
            clutter.append(f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="1.4" ry="0.8" fill="#9A8B74"/>')
        else:
            clutter.append(f'<path d="M{x - 3:.1f},{y:.1f} h6" stroke="#6FA7B4" stroke-width="1"/>')
    return svg(f'<rect width="64" height="32" fill="url(#{terrain})"/>\n' + "\n".join(clutter))


def main(out):
    os.makedirs(out, exist_ok=True)
    for mask in range(1, 15):
        for name, make in (("grass-sand", grass_sand), ("sand-water", sand_water)):
            with open(f"{out}/{name}-{mask:02d}.svg", "w") as f:
                f.write(make(mask, random.Random(f"{name}{mask}")))
    for terrain in ("grass", "sand", "water"):
        for variant in range(3):
            with open(f"{out}/{terrain}-v{variant}.svg", "w") as f:
                f.write(full(terrain, variant))


if __name__ == "__main__":
    main(sys.argv[1])
