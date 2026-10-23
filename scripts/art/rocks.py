"""Rock outcrops for mountain tiles, ray-cast and lit like the trees (change `terrain-v2`, design D5).

Each stone is a convex polytope: an ellipsoid cut by planes. At a region's rim (`sparse`, `medium`)
many shallow cuts make rounded, weathered tors and boulders. Inside (`dense`, `peak`) fewer, deeper
cuts make angular crags, up to 6 m tall on peaks, so a region reads as a hill with a summit rather
than a heap. Taller masses carry a smaller cap set off-centre, every tile keeps gaps where scree
and grass show, and flat tops carry lichen (spring), dry grass (autumn) or snow (winter).
"""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np

from art import flora, ground

# Per density: masses (count, half-width range, height range) and loose boulders.
MASSES = {
    "peak": (2, (1.2, 1.6), (4.0, 6.5)),
    "dense": (2, (1.0, 1.5), (1.6, 3.0)),
    "medium": (2, (1.0, 1.5), (0.8, 1.9)),
    "sparse": (0, (0, 0), (0, 0)),
}
# Masses on these densities are crags: (cuts, how far a cut may bite in). Others are rounded tors.
CRAG = {"dense", "peak"}
ROUNDED_CUTS, CRAG_CUTS = (36, 0.86), (20, 0.72)
BOULDERS = {"peak": 2, "dense": 3, "medium": 3, "sparse": 3}
# The warm sun reddens whatever it lights, so the stone leans cool and green here to read as a
# neutral warm grey, not pink.
STONE = [(0.49, 0.52, 0.55), (0.54, 0.56, 0.58), (0.45, 0.48, 0.51), (0.57, 0.58, 0.58), (0.51, 0.53, 0.54)]
TOPS = {"spring": (0.50, 0.55, 0.46), "autumn": (0.56, 0.55, 0.48), "winter": ground.SNOW}


@dataclass
class Block:
    normals: np.ndarray  # (k, 3) outward unit normals
    offsets: np.ndarray  # (k,) plane offsets: inside where normal . p <= offset
    albedo: np.ndarray


def boulder(rng, centre, radii, tilt: float = 0.15, cuts: tuple[int, float] = ROUNDED_CUTS) -> Block:
    """A stone: an ellipsoid with `radii` (x, y, z) cut by `cuts[0]` planes at random angles, each
    pulled in by up to `1 - cuts[1]`, then leaned by up to `tilt` radians. Many shallow cuts round it
    off; few deep ones leave an angular crag, kept bounded by a box round the ellipsoid. Nothing
    below the ground survives."""
    k, bite = cuts
    dirs = rng.normal(size=(k, 3))
    dirs[:, 1] = np.abs(dirs[:, 1]) * 0.8  # more facets on top and sides than underneath
    dirs /= np.linalg.norm(dirs, axis=1, keepdims=True)
    rx, ry, rz = radii
    support = np.sqrt((rx * dirs[:, 0]) ** 2 + (ry * dirs[:, 1]) ** 2 + (rz * dirs[:, 2]) ** 2)
    offsets = support * rng.uniform(bite, 1.0, len(dirs))
    a, b = rng.uniform(-tilt, tilt, 2)
    lean = np.array([[1, 0, 0], [0, np.cos(a), -np.sin(a)], [0, np.sin(a), np.cos(a)]]) @ np.array(
        [[np.cos(b), -np.sin(b), 0], [np.sin(b), np.cos(b), 0], [0, 0, 1]])
    turn = rng.uniform(0, np.pi)
    spin = np.array([[np.cos(turn), 0, np.sin(turn)], [0, 1, 0], [-np.sin(turn), 0, np.cos(turn)]])
    normals = dirs @ (spin @ lean).T
    centre = np.asarray(centre, float)
    offsets = offsets + normals @ centre
    if k < ROUNDED_CUTS[0]:  # few cuts can leave the polytope open: close it with a box
        box = np.array([[1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, 0, 1], [0, 0, -1]], float)
        normals = np.vstack([normals, box])
        offsets = np.concatenate([offsets, box @ centre + np.array([rx, rx, ry, rz, rz]) * 0.95])
    normals, offsets = np.vstack([normals, [0, -1, 0]]), np.append(offsets, 0.0)  # nothing below the ground
    return Block(normals, offsets, np.array(STONE[rng.integers(len(STONE))]) * rng.uniform(0.92, 1.06))


def tor(rng, x, z, half, height, cuts=ROUNDED_CUTS) -> list[Block]:
    """A mass: a broad base and, on taller ones, a smaller cap set off-centre."""
    base_height = height if height < 2.2 else height * rng.uniform(0.5, 0.65)
    blocks = [boulder(rng, (x, base_height * 0.25, z), (half, base_height * 0.8, half * rng.uniform(0.7, 1.0)), 0.1, cuts)]
    if height >= 2.2:
        cap = half * rng.uniform(0.5, 0.7)
        ox, oz = rng.uniform(-0.35, 0.35, 2) * half
        top = height - base_height
        blocks.append(boulder(rng, (x + ox, base_height * 0.8 + top * 0.3, z + oz), (cap, top * 0.75, cap * 0.85), 0.15, cuts))
    return blocks


def outcrop(density: str, variant: int) -> list[Block]:
    """The stone on one mountain tile. Heights vary a lot between variants, and every tile keeps
    gaps where scree and grass show."""
    rng = flora.rng_for(f"rock-{density}-{variant}")
    count, halves, heights = MASSES[density]
    scale = rng.uniform(0.7, 1.25)  # some tiles hold low, broad stone, others taller tors
    blocks = []
    cuts = CRAG_CUTS if density in CRAG else ROUNDED_CUTS
    for x, z in flora.positions(rng, count, 1.6):
        blocks += tor(rng, x, z, rng.uniform(*halves), rng.uniform(*heights) * scale, cuts)
    for x, z in flora.positions(rng, BOULDERS[density], 1.0):
        r = rng.uniform(0.3, 0.75)
        blocks.append(boulder(rng, (x, r * 0.2, z), (r, r * rng.uniform(0.5, 0.9), r * 0.85), tilt=0.35))
    for x, z in flora.positions(rng, 10, 0.35):  # scree
        r = rng.uniform(0.1, 0.25)
        blocks.append(boulder(rng, (x, r * 0.2, z), (r, r * 0.6, r), tilt=0.4))
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
    top = (n[:, 1] > (0.4 if season == "winter" else 0.8)) & (grain > (0.0 if season == "winter" else 0.55))
    colour[top] = np.array(TOPS[season]) * (0.9 + 0.2 * grain[top, None])
    lambert = np.clip(n @ flora.SUN, 0, 1) * sunlit(p)
    sky = 0.7 + 0.3 * n[:, 1]
    rgb = colour * (ground.SUN_RGB * lambert[:, None] + ground.SKY_RGB * 2.3 * sky[:, None])
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
