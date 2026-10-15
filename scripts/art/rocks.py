"""Rock outcrops for mountain tiles: clusters of faceted blocks, ray-cast and lit like the trees
(change `terrain-v2`, design D4).

Each block is a convex polytope: the intersection of a dozen half-spaces whose normals point
mostly up and out. A ray enters the block at the latest plane it crosses on the way in, so every
facet is flat and catches the sun on its own, which is what makes stone read as stone at sprite
scale. Top-facing facets carry moss (spring), dry grass (autumn) or snow (winter).
"""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np

from art import flora, ground

BLOCKS = {"peak": (3, 4), "dense": (3, 4), "medium": (2, 2), "sparse": (1, 3)}
HEIGHTS = {"peak": (3.2, 6.0), "dense": (1.6, 3.6), "medium": (0.9, 2.0), "sparse": (0.5, 1.1)}
SIZES = {"peak": (2.8, 3.8), "dense": (2.6, 3.6), "medium": (1.8, 2.6), "sparse": (0.7, 1.3)}
STONE = [(0.50, 0.48, 0.46), (0.56, 0.53, 0.49), (0.45, 0.44, 0.44), (0.60, 0.58, 0.55)]
TOPS = {"spring": (0.42, 0.46, 0.30), "autumn": (0.52, 0.48, 0.34), "winter": ground.SNOW}


@dataclass
class Block:
    normals: np.ndarray  # (k, 3) outward unit normals
    offsets: np.ndarray  # (k,) plane offsets: inside where normal . p <= offset
    albedo: np.ndarray


def boulder(rng, centre, radii, tilt: float = 0.15) -> Block:
    """A faceted boulder: an ellipsoid with `radii` (x, y, z) cut by 22 planes at random angles,
    each pulled in a little, then leaned by up to `tilt` radians. Its base sits below the ground."""
    k = 22
    dirs = rng.normal(size=(k, 3))
    dirs[:, 1] = np.abs(dirs[:, 1]) * 0.8  # more facets on top and sides than underneath
    dirs /= np.linalg.norm(dirs, axis=1, keepdims=True)
    rx, ry, rz = radii
    support = np.sqrt((rx * dirs[:, 0]) ** 2 + (ry * dirs[:, 1]) ** 2 + (rz * dirs[:, 2]) ** 2)
    offsets = support * rng.uniform(0.8, 1.0, len(dirs))
    a, b = rng.uniform(-tilt, tilt, 2)
    lean = np.array([[1, 0, 0], [0, np.cos(a), -np.sin(a)], [0, np.sin(a), np.cos(a)]]) @ np.array(
        [[np.cos(b), -np.sin(b), 0], [np.sin(b), np.cos(b), 0], [0, 0, 1]])
    turn = rng.uniform(0, np.pi)
    spin = np.array([[np.cos(turn), 0, np.sin(turn)], [0, 1, 0], [-np.sin(turn), 0, np.cos(turn)]])
    normals = dirs @ (spin @ lean).T
    offsets = offsets + normals @ np.asarray(centre, float)
    normals, offsets = np.vstack([normals, [0, -1, 0]]), np.append(offsets, 0.0)  # nothing below the ground
    return Block(normals, offsets, np.array(STONE[rng.integers(len(STONE))]) * rng.uniform(0.92, 1.06))


def crag(rng, x, z, height, width) -> list[Block]:
    """Ledges of stone stacked to `height`, each narrower than the one below and shifted a little."""
    blocks, base, w = [], 0.0, width
    while base < height - 0.3:
        layer = min(height - base, rng.uniform(0.7, 1.4))
        ox, oz = rng.uniform(-0.25, 0.25, 2) * w
        blocks.append(boulder(rng, (x + ox, base + layer * (0.1 if base == 0 else 0.3), z + oz),
                              (w / 2, layer * 0.75, w / 2 * rng.uniform(0.6, 1.0)), tilt=0.08))
        base += layer * 0.8
        w *= rng.uniform(0.72, 0.9)
    return blocks


def outcrop(density: str, variant: int) -> list[Block]:
    rng = flora.rng_for(f"rock-{density}-{variant}")
    low, high = BLOCKS[density]
    hlow, hhigh = HEIGHTS[density]
    blocks = []
    for x, z in flora.positions(rng, int(rng.integers(low, high + 1)), 1.5):
        width = rng.uniform(*SIZES[density])
        height = rng.uniform(hlow, hhigh)
        if density == "sparse":
            blocks.append(boulder(rng, (x, height * 0.3, z), (width / 2, height * 0.7, width / 2 * 0.8), tilt=0.3))
        else:
            blocks += crag(rng, x, z, height, width)
    for x, z in flora.positions(rng, 10, 0.35):  # scree at the foot
        r = rng.uniform(0.12, 0.3)
        blocks.append(boulder(rng, (x, r * 0.3, z), (r, r * 0.6, r), tilt=0.4))
    return blocks


def _intersect(origins: np.ndarray, direction: np.ndarray, b: Block):
    """Entry distance (inf on a miss) and entry plane index along rays origins + t * direction."""
    along = b.normals @ direction  # (k,)
    start = origins @ b.normals.T  # (n, k)
    with np.errstate(divide="ignore", invalid="ignore"):
        t = (b.offsets - start) / along
    entering = along < 0
    enter = np.where(entering, t, -np.inf)
    leave = np.where(~entering, t, np.inf)
    t_in, t_out = enter.max(1), leave.min(1)
    hit = (t_in < t_out) & (t_out > 0)
    return np.where(hit, t_in, np.inf), enter.argmax(1)


def render(blocks: list[Block], season: str, scale: int = 2) -> np.ndarray:
    """Straight-alpha RGBA (h, w, 4) in 0..1 of the blocks and their ground shadow."""
    s = scale * flora.SUPERSAMPLE
    w, h = flora.WIDTH * s, flora.HEIGHT * s
    sx, sy = np.meshgrid(flora.LEFT + (np.arange(w) + 0.5) / s, flora.TOP + (np.arange(h) + 0.5) / s)
    # Rays start well in front of the tile and travel away from the camera.
    origins = (np.array([2.0, 0, 2.0]) + sx[..., None] / flora.PT_PER_M * flora.RIGHT
               - sy[..., None] / flora.PT_PER_M * flora.UP + 40 * flora.VIEW).reshape(-1, 3)
    best = np.full(len(origins), np.inf)
    normal = np.zeros((len(origins), 3))
    albedo = np.zeros((len(origins), 3))
    for b in blocks:
        t, plane = _intersect(origins, -flora.VIEW, b)
        nearer = t < best
        best[nearer] = t[nearer]
        normal[nearer] = b.normals[plane[nearer]]
        albedo[nearer] = b.albedo
    hit = np.isfinite(best)
    points = origins + best[:, None] * -flora.VIEW

    def sunlit(p):
        lit = np.ones(len(p), bool)
        for b in blocks:
            lit &= ~np.isfinite(_intersect(p + flora.SUN * 0.02, flora.SUN, b)[0])
        return lit

    rgba = np.zeros((len(origins), 4))
    t_ground = (origins @ np.array([0, 1.0, 0])) / flora.VIEW[1]
    ground_pts = origins - t_ground[:, None] * flora.VIEW
    rgba[:, :3] = flora.SHADOW_RGB
    rgba[~hit, 3] = flora.SHADOW_ALPHA * ~sunlit(ground_pts[~hit])

    p, n = points[hit], normal[hit]
    cells = np.floor(p / 0.06)
    grain = flora._hash(cells, 7)
    colour = albedo[hit] * (0.88 + 0.24 * grain[:, None])
    colour *= 1 - 0.08 * (np.sin(p[:, 1] * 9 + 3 * flora._hash(np.floor(p / 0.5), 3)) > 0.6)[:, None]  # strata
    top = (n[:, 1] > (0.55 if season == "winter" else 0.85)) & (grain > (0.0 if season == "winter" else 0.45))
    colour[top] = np.array(TOPS[season]) * (0.9 + 0.2 * grain[top, None])
    lambert = np.clip(n @ flora.SUN, 0, 1) * sunlit(p)
    sky = 0.7 + 0.3 * n[:, 1]
    rgb = colour * (ground.SUN_RGB * lambert[:, None] + ground.SKY_RGB * 1.9 * sky[:, None])
    rgba[hit, :3] = np.clip(rgb, 0, 1)
    rgba[hit, 3] = 1
    rgba = rgba.reshape(h, w, 4)
    pre = np.concatenate([rgba[..., :3] * rgba[..., 3:], rgba[..., 3:]], -1)
    k = flora.SUPERSAMPLE
    pre = pre.reshape(h // k, k, w // k, k, 4).mean((1, 3))
    alpha = pre[..., 3:]
    return np.concatenate([np.where(alpha > 0, pre[..., :3] / np.maximum(alpha, 1e-6), 0), alpha], -1)


def sprite(density: str, variant: int, season: str, scale: int = 2) -> np.ndarray:
    return render(outcrop(density, variant), season, scale)
