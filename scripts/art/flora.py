"""Tree clumps for forest tiles, ray-cast from spheres and lit like the IsoKit rig (change
`terrain-v2`, design D3).

A clump is the trees standing on one 4 m tile, drawn as one sprite that the renderer depth-sorts
with the buildings. Every tree is a cloud of leaf clumps (spheres) round a trunk. Each pixel takes
the nearest sphere; its normal is roughened with noise and lit by the warm sun, with soft shadows
through the canopy, plus the cool sky scaled by how deep in the crown it sits. The canopy also
shades the ground, so the sprite carries the clump's cast shadow, as kit buildings do.

World axes as in IsoKit: x = +col, z = +row, y = up; a tile spans x, z in [0, 4].
"""

from __future__ import annotations

import zlib
from dataclasses import dataclass, field

import numpy as np

from art import ground

PT_PER_M = 64 / (2**0.5 * 4)  # 11.31 points per metre in the view plane
RIGHT = np.array([1, 0, -1]) / 2**0.5  # screen right, in world axes
UP = np.array([-0.5 / 2**0.5, 3**0.5 / 2, -0.5 / 2**0.5])  # screen up (IsoKit `Iso.up`)
VIEW = np.cross(RIGHT, UP)  # towards the camera
SUN = ground.SUN  # (u, up, v) is (x, y, z)
SHADOW_RGB = np.array([0.12, 0.08, 0.05])
SHADOW_ALPHA = 0.55  # IsoKit's `Rig` shadow colour alpha

# The sprite, in points about the tile centre (x right, y down): trees reach 9 m up and cast their
# shadow to the right.
LEFT, TOP, WIDTH, HEIGHT = -56, -112, 144, 132
SUPERSAMPLE = 2


@dataclass
class Spheres:
    centre: list = field(default_factory=list)
    radius: list = field(default_factory=list)
    albedo: list = field(default_factory=list)
    leafy: list = field(default_factory=list)  # roughened normals; conifer needles catch snow
    crown: list = field(default_factory=list)  # (centre, radius) of the crown, for sky shading

    def add(self, centre, radius, albedo, leafy=True, crown=None):
        centre = np.asarray(centre, float)
        self.centre.append(centre)
        self.radius.append(float(radius))
        self.albedo.append(np.asarray(albedo, float))
        self.leafy.append(leafy)
        self.crown.append(crown if crown is not None else (centre, float(radius)))

    def arrays(self):
        return (np.array(self.centre), np.array(self.radius), np.array(self.albedo), np.array(self.leafy),
                np.array([c for c, _ in self.crown]), np.array([r for _, r in self.crown]))


def rng_for(name: str) -> np.random.Generator:
    return np.random.default_rng(zlib.crc32(name.encode()))


LEAVES = {
    "spring": [(0.29, 0.45, 0.15), (0.34, 0.50, 0.16), (0.40, 0.54, 0.18), (0.31, 0.43, 0.17), (0.45, 0.56, 0.22)],
    "autumn": [(0.62, 0.40, 0.13), (0.66, 0.52, 0.17), (0.54, 0.30, 0.12), (0.50, 0.48, 0.18), (0.70, 0.58, 0.22)],
}
NEEDLES = (0.16, 0.29, 0.19)
BARK = (0.27, 0.22, 0.18)
TWIGS = (0.36, 0.31, 0.27)


def trunk(spheres: Spheres, base, top, radius) -> None:
    base, top = np.asarray(base, float), np.asarray(top, float)
    steps = max(2, int(np.linalg.norm(top - base) / (radius * 0.6)))
    for t in np.linspace(0, 1, steps):
        spheres.add(base + (top - base) * t, radius * (1 - 0.35 * t), BARK, leafy=False)


def broadleaf(spheres: Spheres, rng, x, z, height, season) -> None:
    centre = np.array([x, height * 0.62, z])
    rh, rv = height * rng.uniform(0.22, 0.28), height * rng.uniform(0.34, 0.4)
    if season == "winter":
        bare(spheres, rng, x, z, height, centre, rh, rv)
        return
    trunk(spheres, (x, 0, z), centre, 0.09 + 0.008 * height)
    tone = np.array(LEAVES[season][rng.integers(len(LEAVES[season]))]) * rng.uniform(0.9, 1.1)
    scale = np.array([rh, rv, rh])
    crown = (centre, max(rh, rv))
    spheres.add(centre, min(rh, rv) * 0.8, tone * 0.7, crown=crown)
    for _ in range(int(40 + 6 * height)):
        d = rng.normal(size=3)
        d /= np.linalg.norm(d)
        spheres.add(centre + d * scale * rng.uniform(0.55, 0.92), rng.uniform(0.42, 0.68) * height / 8,
                    tone * rng.uniform(0.85, 1.12), crown=crown)


def bare(spheres: Spheres, rng, x, z, height, centre, rh, rv) -> None:
    """A broadleaf tree in winter: trunk, limbs forking down to a haze of twigs."""
    fork = np.array([x, height * 0.42, z])
    trunk(spheres, (x, 0, z), fork, 0.1 + 0.008 * height)

    def limb(start, direction, length, radius, depth):
        end = start + direction * length
        steps = max(2, int(length / (radius * 0.9)))
        for t in np.linspace(0, 1, steps):
            spheres.add(start + (end - start) * t, radius, BARK if depth < 2 else TWIGS, leafy=False)
        if depth == 5:
            return
        for _ in range(rng.integers(2, 4)):
            bend = direction + rng.normal(size=3) * 0.6 + np.array([0, 0.25, 0])
            limb(end, bend / np.linalg.norm(bend), length * 0.66, max(radius * 0.6, 0.018), depth + 1)

    for _ in range(rng.integers(3, 5)):
        d = rng.normal(size=3) * np.array([1, 0, 1])
        d = d / np.linalg.norm(d) * 0.55 + np.array([0, 0.85, 0])
        limb(fork, d / np.linalg.norm(d), height * 0.2, 0.09, 0)


def conifer(spheres: Spheres, rng, x, z, height, season) -> None:
    """A spruce: a trunk inside a cone of needle clumps that droops in tiers."""
    base = height * rng.uniform(0.1, 0.16)
    radius = height * rng.uniform(0.16, 0.2)
    trunk(spheres, (x, 0, z), (x, height * 0.9, z), 0.08 + 0.006 * height)
    tone = np.array(NEEDLES) * rng.uniform(0.9, 1.1)
    tier = (height - base) / 6
    for y in np.linspace(base, height, 12):
        r = radius * (1 - (y - base) / (height - base)) + 0.1
        spheres.add((x, y, z), r * 0.6, tone * 0.7, crown=(np.array([x, y, z]), r))
    for _ in range(int(26 * height)):
        y = base + (height - base) * rng.random() ** 1.3
        taper = 1 - (y - base) / (height - base)
        skirt = 0.7 + 0.3 * ((y - base) / tier % 1)  # each tier widest at its bottom
        r = (radius * taper * (1.3 - skirt) / 0.6 + 0.08) * rng.uniform(0.8, 1.0)
        angle = rng.uniform(0, 2 * np.pi)
        p = (x + np.cos(angle) * r, y, z + np.sin(angle) * r)
        spheres.add(p, rng.uniform(0.2, 0.3) * height / 9, tone * rng.uniform(0.85, 1.12),
                    crown=(np.array([x, y, z]), radius * taper + 0.1))


def bush(spheres: Spheres, rng, x, z, season) -> None:
    if season == "winter":
        return
    tone = np.array(LEAVES[season][rng.integers(len(LEAVES[season]))]) * 0.85
    centre = np.array([x, 0.35, z])
    for _ in range(9):
        spheres.add(centre + rng.normal(size=3) * np.array([0.35, 0.15, 0.35]), rng.uniform(0.25, 0.4), tone,
                    crown=(centre, 0.6))


TREES = {"dense": (5, 7), "medium": (3, 4), "sparse": (1, 2), "single": (1, 1)}


def positions(rng, count: int, spacing: float) -> list[tuple[float, float]]:
    """Up to `count` trunk positions in the tile, at least `spacing` apart, by dart throwing."""
    found: list[tuple[float, float]] = []
    for _ in range(400):
        if len(found) == count:
            break
        p = tuple(rng.uniform(0.55, 3.45, 2))
        if all(np.hypot(p[0] - q[0], p[1] - q[1]) >= spacing for q in found):
            found.append(p)
    return found


def clump(density: str, variant: int, season: str) -> Spheres:
    """The trees of one forest tile. The seed ignores the season, so a clump keeps its trees all year."""
    rng = rng_for(f"forest-{density}-{variant}")
    low, high = TREES[density]
    spots = positions(rng, int(rng.integers(low, high + 1)), 1.35)
    trees = [(rng.random() < 0.3, rng.uniform(5.5, 8.0), int(rng.integers(2**31))) for _ in spots]
    spheres = Spheres()
    for (x, z), (is_conifer, height, seed) in zip(spots, trees):
        (conifer if is_conifer else broadleaf)(spheres, np.random.default_rng(seed), x, z, height, season)
    for x, z in positions(rng, {"single": 1, "sparse": 3}.get(density, 2), 0.8):
        bush(spheres, rng, x, z, season)
    return spheres


LEAF = 0.09  # metres: leaf clusters are about one @2x pixel across


def _hash(cells: np.ndarray, salt: int) -> np.ndarray:
    """A float in [0, 1) per integer 3D cell, stable across runs and platforms."""
    c = cells.astype(np.int64) & 0xFFFFF
    h = (c[..., 0] * 73856093) ^ (c[..., 1] * 19349663) ^ (c[..., 2] * 83492791) ^ salt
    h = (h ^ (h >> 13)) * 1274126177 & 0xFFFFFFFF
    return ((h ^ (h >> 16)) & 0xFFFF) / 65536.0


def _leaves(points: np.ndarray) -> np.ndarray:
    """Per-leaf random vectors in [-1, 1]^3 and a coverage value, from the leaf cell each point is in."""
    cells = np.floor(points / LEAF)
    return np.stack([_hash(cells, k) for k in range(4)], -1) * 2 - 1


def _project(points: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Screen points (x right, y down) about the tile centre, for world points in the tile."""
    rel = points - np.array([2.0, 0.0, 2.0])
    return PT_PER_M * rel @ RIGHT, -PT_PER_M * rel @ UP


def _transmittance(points: np.ndarray, centre, radius) -> np.ndarray:
    """How much sunlight reaches each point: every sphere the sun ray passes near dims it."""
    light = np.ones(len(points))
    for c, r in zip(centre, radius):
        if r < 0.06:
            continue  # twigs are too thin to cast a shadow worth the time
        oc = c - points
        along = oc @ SUN
        ahead = along > 0.05
        if not ahead.any():
            continue
        miss = np.sqrt(np.maximum((oc * oc).sum(1) - along**2, 0))
        light *= 1 - 0.75 * np.clip((r * 1.05 - miss) / (r * 0.6), 0, 1) * ahead
    return light


def _upsample(field: np.ndarray, q: int) -> np.ndarray:
    """Bilinear upsampling by `q`, for the quarter-resolution ground shadow."""
    rows = np.clip((np.arange(field.shape[0] * q) + 0.5) / q - 0.5, 0, field.shape[0] - 1)
    cols = np.clip((np.arange(field.shape[1] * q) + 0.5) / q - 0.5, 0, field.shape[1] - 1)
    r0, c0 = np.floor(rows).astype(int), np.floor(cols).astype(int)
    r1, c1 = np.minimum(r0 + 1, field.shape[0] - 1), np.minimum(c0 + 1, field.shape[1] - 1)
    fr, fc = (rows - r0)[:, None], (cols - c0)[None, :]
    top = field[r0][:, c0] * (1 - fc) + field[r0][:, c1] * fc
    bottom = field[r1][:, c0] * (1 - fc) + field[r1][:, c1] * fc
    return top * (1 - fr) + bottom * fr


def render(spheres: Spheres, season: str, scale: int = 2) -> np.ndarray:
    """Straight-alpha RGBA (h, w, 4) in 0..1 of the spheres and their ground shadow, `scale` px per point."""
    s = scale * SUPERSAMPLE
    w, h = WIDTH * s, HEIGHT * s
    sx, sy = np.meshgrid(LEFT + (np.arange(w) + 0.5) / s, TOP + (np.arange(h) + 0.5) / s)
    centre, radius, albedo, leafy, crown_c, crown_r = spheres.arrays()
    cx, cy = _project(centre)
    depth = np.full((h, w), -np.inf)
    hit = np.full((h, w), -1)
    for i in range(len(radius)):
        rp = radius[i] * PT_PER_M
        x0, x1 = max(int((cx[i] - rp - LEFT) * s), 0), min(int((cx[i] + rp - LEFT) * s) + 1, w)
        y0, y1 = max(int((cy[i] - rp - TOP) * s), 0), min(int((cy[i] + rp - TOP) * s) + 1, h)
        if x0 >= x1 or y0 >= y1:
            continue
        a = (sx[y0:y1, x0:x1] - cx[i]) / PT_PER_M
        b = -(sy[y0:y1, x0:x1] - cy[i]) / PT_PER_M
        t2 = radius[i] ** 2 - a * a - b * b
        t = np.sqrt(np.maximum(t2, 0))
        if leafy[i]:
            front = centre[i] + a[..., None] * RIGHT + b[..., None] * UP + t[..., None] * VIEW
            gap = _leaves(front)[..., 3]
            t2 = np.where(t / radius[i] < 0.45 * (gap + 1), -1, t2)  # ragged edges between leaf clusters
        d = np.where(t2 > 0, centre[i] @ VIEW + t, -np.inf)
        better = d > depth[y0:y1, x0:x1]
        depth[y0:y1, x0:x1] = np.where(better, d, depth[y0:y1, x0:x1])
        hit[y0:y1, x0:x1] = np.where(better, i, hit[y0:y1, x0:x1])

    # Ground shadow: the canopy's transmittance at the ground point under each pixel.
    # Ground shadow, soft anyway, so worked out at a quarter of the resolution.
    q = 4
    gsx, gsy = sx[q // 2 :: q, q // 2 :: q], sy[q // 2 :: q, q // 2 :: q]
    gx, gz = (gsx / 8 + gsy / 4) / 2 + 2, (gsy / 4 - gsx / 8) / 2 + 2
    ground_pts = np.stack([gx, np.zeros_like(gx), gz], -1).reshape(-1, 3)
    shadow = 1 - _transmittance(ground_pts, centre, radius).reshape(gx.shape)
    rgba = np.zeros((h, w, 4))
    rgba[..., :3] = SHADOW_RGB
    rgba[..., 3] = SHADOW_ALPHA * _upsample(shadow, q)[:h, :w]

    ys, xs = np.nonzero(hit >= 0)
    idx = hit[ys, xs]
    a = (sx[ys, xs] - cx[idx]) / PT_PER_M
    b = -(sy[ys, xs] - cy[idx]) / PT_PER_M
    t = np.sqrt(np.maximum(radius[idx] ** 2 - a * a - b * b, 0))
    points = centre[idx] + a[:, None] * RIGHT + b[:, None] * UP + t[:, None] * VIEW
    noise = _leaves(points)
    normal = (points - centre[idx]) / radius[idx, None] + 0.7 * noise[:, :3] * leafy[idx, None]
    normal /= np.linalg.norm(normal, axis=1, keepdims=True)
    light = _transmittance(points + normal * 0.05, centre, radius)
    lambert = np.clip(normal @ SUN, 0, 1)
    inner = np.linalg.norm(points - crown_c[idx], axis=1) / np.maximum(crown_r[idx], 1e-3)
    sky = (0.55 + 0.45 * np.clip(inner, 0, 1) ** 1.5) * (0.8 + 0.2 * normal[:, 1])
    colour = albedo[idx] * (1 + 0.15 * noise[:, 3:] * leafy[idx, None])
    if season == "winter":
        needles = leafy[idx] & (normal[:, 1] > 0.45)
        colour[needles] = ground.SNOW
    rgb = colour * (ground.SUN_RGB * (lambert * light)[:, None] + ground.SKY_RGB * 1.2 * sky[:, None])
    rgba[ys, xs, :3] = np.clip(rgb, 0, 1)
    rgba[ys, xs, 3] = 1
    pre = np.concatenate([rgba[..., :3] * rgba[..., 3:], rgba[..., 3:]], -1)
    pre = pre.reshape(h // SUPERSAMPLE, SUPERSAMPLE, w // SUPERSAMPLE, SUPERSAMPLE, 4).mean((1, 3))
    alpha = pre[..., 3:]
    return np.concatenate([np.where(alpha > 0, pre[..., :3] / np.maximum(alpha, 1e-6), 0), alpha], -1)


def sprite(density: str, variant: int, season: str, scale: int = 2) -> np.ndarray:
    return render(clump(density, variant, season), season, scale)
