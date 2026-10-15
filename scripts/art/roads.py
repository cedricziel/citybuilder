"""Road tiles that join their neighbours (capability `iso-art-kit`).

A road tile is drawn over the terrain and is transparent where there is no road. Its connection
mask has four arm bits, one per edge neighbour that is paved (a road, or the town center's
footprint), and four corner bits, set when two adjacent arms are paved and so is the diagonal tile
between them:

    arms:    +u = 1, +v = 2, -u = 4, -v = 8
    corners: (+u,+v) = 16, (-u,+v) = 32, (-u,-v) = 64, (+u,-v) = 128

Arms are bands of one fixed width running from the tile centre to an edge midpoint, so neighbours
meet without a step; a corner fills the quadrant between its arms right up to the shared vertex,
which closes 2 x 2 blocks of road. Corners only exist where the diagonal is paved too, so a filled
quadrant always meets filled quadrants across both of its edges.

Two surfaces: worn earth with gravel and wheel ruts, and cobbles for the plaza ring round the town
center. Both are tile-periodic and lit like the terrain (`art.ground`).
"""

from __future__ import annotations

import base64
import functools
import io

import numpy as np
from PIL import Image

from art import ground

HALF = 0.24  # half the road's width, in tile units
SOFT = 0.05  # width of the edge fade
ARMS = ((1, (1, 0)), (2, (0, 1)), (4, (-1, 0)), (8, (0, -1)))
CORNERS = ((16, 1, 2), (32, 4, 2), (64, 4, 8), (128, 1, 8))
SURFACES = ("earth", "plaza")
SCALE = 4  # rasterise at 4x the @1x tile, then let rsvg scale down


def masks() -> list[int]:
    """Every mask a road can have: any arms, plus any subset of the corners its arms allow."""
    out = []
    for arms in range(16):
        allowed = [bit for bit, a, b in CORNERS if arms & a and arms & b]
        for subset in range(1 << len(allowed)):
            out.append(arms | sum(bit for i, bit in enumerate(allowed) if subset >> i & 1))
    return out


def _uv() -> tuple[np.ndarray, np.ndarray]:
    u = (np.arange(ground.SIZE) + 0.5) / ground.SIZE
    return np.meshgrid(u, u, indexing="ij")


def distance(mask: int, uu: np.ndarray, vv: np.ndarray) -> np.ndarray:
    """Signed distance in tile units to the road edge at points (u, v), negative on the road. Points
    may lie just outside the tile."""
    du, dv = uu - 0.5, vv - 0.5
    dist = np.hypot(du, dv) - HALF
    for bit, (au, av) in ARMS:
        if mask & bit:
            along, across = du * au + dv * av, np.abs(du * av - dv * au)
            dist = np.minimum(dist, np.where(along > 0, across - HALF, np.hypot(du, dv) - HALF))
    for bit, a, b in CORNERS:
        if mask & bit:
            (_, (au, av)), (_, (bu, bv)) = ARMS[[1, 2, 4, 8].index(a)], ARMS[[1, 2, 4, 8].index(b)]
            inside = np.maximum(-(du * au + dv * av), -(du * bu + dv * bv))  # <= 0 inside the quadrant
            dist = np.minimum(dist, inside)
    return dist


def coverage(mask: int, uu: np.ndarray, vv: np.ndarray) -> np.ndarray:
    """Road cover 0..1, faded over `SOFT` at the edge."""
    return np.clip(0.5 - distance(mask, uu, vv) / SOFT, 0, 1)


@functools.cache
def surface(name: str) -> np.ndarray:
    """Lit, tile-periodic RGB for a road surface."""
    uu, vv = _uv()
    if name == "earth":
        tone = 0.5 + 0.28 * ground.noise("road-earth", 0.35) + 0.12 * ground.noise("road-grit", 0.03, sharp=1.0)
        albedo = ground.mix([(0.44, 0.37, 0.27), (0.57, 0.49, 0.36), (0.68, 0.61, 0.47)], tone)
        gravel = ground.noise("road-gravel", 0.025, sharp=1.0) > 0.55
        albedo[gravel] = (0.64, 0.61, 0.56)
        height = 0.015 * ground.noise("road-bumps", 0.1) + 0.02 * gravel
        return ground.shade(ground.Surface(height, albedo))
    # Cobbles: a running-bond grid of rounded stones, 6 x 6 per tile so the pattern repeats per tile.
    rows = 8
    row = np.floor(vv * rows)
    col = (uu * rows + 0.5 * (row % 2)) % 1
    cell_u, cell_v = col - 0.5, (vv * rows) % 1 - 0.5
    stone = np.clip(1 - (np.abs(cell_u) ** 3 + np.abs(cell_v) ** 3) * 9, 0, 1)
    height = 0.05 * np.sqrt(stone)
    tone = 0.5 + 0.25 * ground.noise("cobble-tone", 0.08) + 0.1 * ground.noise("cobble-wear", 0.4)
    albedo = ground.mix([(0.58, 0.52, 0.43), (0.70, 0.63, 0.51), (0.80, 0.73, 0.60)], tone)
    albedo[stone < 0.05] = (0.44, 0.40, 0.33)  # joints
    return ground.shade(ground.Surface(height, albedo))


def tile_image(mask: int, surface_name: str) -> Image.Image:
    """The tile at 4x (256 x 128), anchored like terrain, with a 1-point bleed past the diamond."""
    width, height = 64 * SCALE, 32 * SCALE
    ys, xs = np.mgrid[0:height, 0:width]
    sx, sy = (xs + 0.5 - width / 2) / (width / 2), (ys + 0.5) / (height / 2)
    uu, vv = (sx + sy) / 2, (sy - sx) / 2
    bleed = 1 / 32  # one point, in tile units along an edge
    inside = (uu > -bleed) & (uu < 1 + bleed) & (vv > -bleed) & (vv < 1 + bleed)
    texels = surface(surface_name)
    iu = (np.mod(uu, 1) * ground.SIZE).astype(int) % ground.SIZE
    iv = (np.mod(vv, 1) * ground.SIZE).astype(int) % ground.SIZE
    dist = distance(mask, uu, vv)
    alpha = np.clip(0.5 - dist / SOFT, 0, 1) * inside
    # Wear: the crown is trodden lighter, the verges darker where grass and mud meet the road.
    wear = 0.86 + 0.2 * np.clip(-dist / HALF, 0, 1)
    rgba = np.concatenate([np.clip(texels[iu, iv] * wear[..., None], 0, 1), alpha[..., None]], axis=-1)
    return Image.fromarray((rgba * 255 + 0.5).astype(np.uint8), "RGBA")


def svg(mask: int, surface_name: str) -> str:
    buffer = io.BytesIO()
    tile_image(mask, surface_name).save(buffer, format="PNG", optimize=True)
    uri = "data:image/png;base64," + base64.b64encode(buffer.getvalue()).decode()
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="32" viewBox="0 0 64 32">\n'
        f'<image width="64" height="32" href="{uri}"/>\n</svg>\n'
    )


def name(mask: int, surface_name: str) -> str:
    return f"building-road-c{mask}" if surface_name == "earth" else f"building-road-plaza-c{mask}"


def sources() -> dict[str, str]:
    """Every road sprite: each mask on each surface, the base sprite (a straight +u/-u road, the
    build rail's icon) and three construction stages."""
    tiles = {name(mask, s): svg(mask, s) for s in SURFACES for mask in masks()}
    tiles["building-road"] = svg(1 | 4, "earth")
    for stage, mask in enumerate((0, 1 | 4, 1 | 4)):
        tiles[f"building-road-constructing-{stage}"] = svg(mask, "earth")
    return tiles
