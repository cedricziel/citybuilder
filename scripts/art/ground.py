"""Painterly, lit ground textures for the terrain tiles (capability `iso-art-kit`, design D6).

Every texture lives in tile space (u, v) and repeats with period 1 in both, so any two tiles join
without a seam, whatever they sit next to. Each terrain is a small heightfield in metres (a tile is
4 m across) and an albedo, lit like the IsoKit rig: a warm sun from the upper left and a cool sky.
Noise comes from filtering white noise in the frequency domain, which is periodic by construction.
"""

from __future__ import annotations

import base64
import io
from dataclasses import dataclass

import numpy as np
from PIL import Image

SIZE = 256  # texels per tile edge in (u, v)
TILE_METRES = 4.0
# Towards the sun and towards the camera, in (u, up, v): IsoKit's sun sits at (-9, 30, 9) from the
# scene centre, and the camera looks down 30 degrees from the south-east.
SUN = np.array([-9.0, 30.0, 9.0]) / np.linalg.norm([-9.0, 30.0, 9.0])
VIEW = np.array([0.612, 0.5, 0.612])
SUN_RGB = np.array([1.0, 0.80, 0.56]) * 0.84
SKY_RGB = np.array([0.74, 0.70, 0.70]) * 0.36


@dataclass(frozen=True)
class Surface:
    height: np.ndarray  # metres, SIZE x SIZE
    albedo: np.ndarray  # linear-ish RGB 0..1, SIZE x SIZE x 3
    gloss: float = 0.0  # specular strength (water)


def noise(seed: str, wavelength: float, sharp: float = 2.0) -> np.ndarray:
    """Periodic band-limited noise with features about `wavelength` tiles across, scaled to -1..1."""
    rng = np.random.default_rng(int.from_bytes(seed.encode(), "little") % 2**63)
    white = rng.standard_normal((SIZE, SIZE))
    freq = np.fft.fftfreq(SIZE) * SIZE  # cycles per tile
    radius = np.hypot(*np.meshgrid(freq, freq, indexing="ij"))
    centre = 1.0 / wavelength
    band = np.exp(-((np.log((radius + 1e-6) / centre)) ** 2) * sharp)
    band[0, 0] = 0
    field = np.real(np.fft.ifft2(np.fft.fft2(white) * band))
    return field / (np.abs(field).max() or 1)


def mix(colours: list[tuple[float, float, float]], t: np.ndarray) -> np.ndarray:
    """Blend a ramp of colours by t in 0..1."""
    ramp = np.array(colours)
    pos = np.clip(t, 0, 1) * (len(ramp) - 1)
    low = np.floor(pos).astype(int).clip(0, len(ramp) - 2)
    frac = (pos - low)[..., None]
    return ramp[low] * (1 - frac) + ramp[low + 1] * frac


def shade(surface: Surface) -> np.ndarray:
    """Lit RGB 0..1: sun with soft cast shadows, sky scaled by cavity, and a sun glint for water."""
    h = surface.height
    step = TILE_METRES / SIZE
    du = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) / (2 * step)
    dv = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) / (2 * step)
    normal = np.stack([-du, np.ones_like(h), -dv], axis=-1)
    normal /= np.linalg.norm(normal, axis=-1, keepdims=True)
    lambert = np.clip(normal @ SUN, 0, 1)
    lit = np.ones_like(h)
    for texels in (2, 4, 8, 16, 32):  # march towards the sun; periodic, so roll wraps
        ahead = np.roll(h, (-round(SUN[0] / np.hypot(SUN[0], SUN[2]) * texels), -round(SUN[2] / np.hypot(SUN[0], SUN[2]) * texels)), (0, 1))
        rise = texels * step * SUN[1] / np.hypot(SUN[0], SUN[2])
        lit = np.minimum(lit, np.clip(1 - (ahead - h - rise) * 4, 0, 1))
    blurred = np.real(np.fft.ifft2(np.fft.fft2(h) * np.exp(-(np.hypot(*np.meshgrid(np.fft.fftfreq(SIZE), np.fft.fftfreq(SIZE), indexing="ij")) * SIZE / 6) ** 2)))
    cavity = np.clip(1 + (h - blurred) * 2.5, 0.55, 1.1)
    light = SUN_RGB * (lambert * lit)[..., None] + SKY_RGB * cavity[..., None]
    rgb = surface.albedo * light
    if surface.gloss:
        half = (SUN + VIEW) / np.linalg.norm(SUN + VIEW)
        rgb += SUN_RGB * surface.gloss * (np.clip(normal @ half, 0, 1) ** 40)[..., None] * lit[..., None]
    return np.clip(rgb, 0, 1)


def to_data_uri(rgb: np.ndarray) -> str:
    """The texture as a PNG data URI for an SVG `<image>`, with u across and v down."""
    image = Image.fromarray((rgb.transpose(1, 0, 2) * 255 + 0.5).astype(np.uint8), "RGB")
    buffer = io.BytesIO()
    image.save(buffer, format="PNG", optimize=True)
    return "data:image/png;base64," + base64.b64encode(buffer.getvalue()).decode()


GRASS = {
    "spring": [(0.20, 0.36, 0.15), (0.29, 0.47, 0.19), (0.40, 0.55, 0.25), (0.52, 0.60, 0.33)],
    "autumn": [(0.33, 0.36, 0.17), (0.45, 0.45, 0.22), (0.56, 0.50, 0.27), (0.64, 0.56, 0.34)],
    "winter": [(0.36, 0.42, 0.28), (0.70, 0.76, 0.80), (0.84, 0.90, 0.98), (0.90, 0.95, 1.00)],
}


def grass(season: str = "spring", frame: int = 0) -> Surface:
    """Meadow: broad light and dark patches, clumps, and blade stipple that sways between frames."""
    broad, clumps = noise("grass-broad", 0.7), noise("grass-clumps", 0.18)
    blades = noise(f"grass-blades-{frame}", 0.035, sharp=1.0)
    tone = 0.5 + 0.32 * broad + 0.16 * clumps + 0.1 * blades + (0.22 if season == "winter" else 0)
    albedo = mix(GRASS[season], tone)
    height = 0.05 * clumps + 0.015 * blades
    return Surface(height, albedo)


def beach(frame: int = 0) -> Surface:
    """Sand with wind ripples, darker damp patches and the odd pebble."""
    u = np.linspace(0, 1, SIZE, endpoint=False)
    uu, vv = np.meshgrid(u, u, indexing="ij")
    ripples = np.sin(2 * np.pi * (6 * uu + 9 * vv) + 1.5 * noise("sand-warp", 0.3))
    damp = noise("sand-damp", 0.6)
    tone = 0.55 + 0.25 * damp + 0.05 * ripples + 0.06 * noise(f"sand-grain-{frame}", 0.03, sharp=1.0)
    albedo = mix([(0.60, 0.56, 0.47), (0.73, 0.68, 0.57), (0.84, 0.79, 0.68)], tone)
    pebbles = noise("sand-pebbles", 0.05) > 0.8
    albedo[pebbles] = (0.55, 0.52, 0.47)
    return Surface(0.02 * ripples + 0.04 * pebbles, albedo)


def water(frame: int = 0, frames: int = 4) -> Surface:
    """Swell from a few integer wave vectors, so it stays periodic in space and loops over `frames`."""
    u = np.linspace(0, 1, SIZE, endpoint=False)
    uu, vv = np.meshgrid(u, u, indexing="ij")
    phase = 2 * np.pi * frame / frames
    waves = [((2, 1), 0.03, 1), ((-1, 3), 0.018, 2), ((5, -2), 0.008, 1), ((4, 7), 0.004, 3)]
    warp = 0.6 * noise("water-warp", 0.4)
    height = sum(amp * np.sin(2 * np.pi * (ku * uu + kv * vv) + warp - speed * phase) for (ku, kv), amp, speed in waves)
    height = height + 0.006 * noise(f"water-chop-{frame % frames}", 0.06)
    depth = 0.5 + 0.3 * noise("water-depth", 0.8)
    albedo = mix([(0.10, 0.27, 0.33), (0.16, 0.38, 0.44), (0.24, 0.48, 0.52)], depth)
    return Surface(height, albedo, gloss=0.5)


def _grid() -> tuple[np.ndarray, np.ndarray]:
    u = np.linspace(0, 1, SIZE, endpoint=False)
    return np.meshgrid(u, u, indexing="ij")


def _wrapped_distance(uu: np.ndarray, vv: np.ndarray, cu: float, cv: float) -> np.ndarray:
    """Distance in tiles to (cu, cv) on the torus, so crowns near an edge reappear across it."""
    du = (uu - cu + 0.5) % 1 - 0.5
    dv = (vv - cv + 0.5) % 1 - 0.5
    return np.hypot(du, dv)


FOLIAGE = {
    "spring": [(0.20, 0.36, 0.14), (0.27, 0.44, 0.16), (0.34, 0.48, 0.18)],
    "autumn": [(0.56, 0.36, 0.14), (0.62, 0.50, 0.18), (0.46, 0.26, 0.12)],
    "winter": [(0.50, 0.46, 0.41), (0.54, 0.50, 0.45), (0.46, 0.43, 0.39)],
}
CONIFER = (0.14, 0.28, 0.16)
SNOW = (0.84, 0.90, 0.98)  # cool, so the warm sun leaves it white rather than cream


def forest(season: str = "spring") -> Surface:
    """A closed canopy of 20 crowns per tile, scattered rather than gridded so the repeat is hard to
    see. A quarter are conifers: they keep their needles in winter and catch snow on top, while the
    bare broadleaf crowns turn into a thin lace of twigs over the snow."""
    rng = np.random.default_rng(7)
    uu, vv = _grid()
    winter = season == "winter"
    height = np.full((SIZE, SIZE), -0.4)
    albedo = np.empty((SIZE, SIZE, 3))
    albedo[:] = SNOW if winter else (0.20, 0.19, 0.11)
    leaves = noise("forest-leaves", 0.03, sharp=1.0)
    twigs = np.abs(noise("forest-twigs", 0.025, sharp=0.5)) < 0.5
    crowns = [(rng.random(), rng.random(), rng.uniform(0.09, 0.15), rng.random() < 0.25) for _ in range(20)]
    for cu, cv, radius, conifer in crowns:
        bare = winter and not conifer
        d = _wrapped_distance(uu, vv, cu, cv) / radius
        lift = 0.3 * rng.random()
        crown = np.sqrt(np.clip(1 - d**2, 0, 1)) * radius * TILE_METRES * (0.4 if bare else 1.1) + lift
        inside = (d < 1) & (crown > height)
        if bare:
            inside &= twigs
        height = np.where(inside, crown, height)
        base = CONIFER if conifer else FOLIAGE[season][rng.integers(3)]
        colour = np.array(base) * (0.9 + 0.2 * rng.random())
        albedo[inside] = colour * (1 + 0.25 * leaves[inside, None])
        if winter and conifer:
            snowy = inside & (d < 0.75) & ((uu - cu + 0.5) % 1 - 0.5 < 0.02)
            albedo[snowy] = 0.5 * albedo[snowy] + 0.5 * np.array(SNOW)
    return Surface(height, np.clip(albedo, 0, 1))


def rock(variant: int = 0) -> Surface:
    """Grey rock in big, rounded forms with a little ridged detail.
    Variants add boulders inside a window that is zero on the tile edges, so every variant still
    joins every neighbour."""
    uu, vv = _grid()
    forms = noise("rock-forms", 0.6)
    ridges = 1 - np.abs(noise("rock-ridges", 0.22))
    height = 0.7 * forms + 0.2 * ridges**2 + 0.03 * noise("rock-grain", 0.05)
    if variant:
        window = (np.sin(np.pi * uu) * np.sin(np.pi * vv)) ** 2
        boulders = np.clip(noise(f"rock-boulders-{variant}", 0.25), 0, 1) ** 0.7
        height = height + 0.7 * window * boulders
    tone = 0.5 + 0.2 * noise("rock-strata", 0.3) + 0.25 * (height - height.mean()) / (np.ptp(height) or 1)
    albedo = mix([(0.46, 0.47, 0.48), (0.61, 0.61, 0.61), (0.76, 0.76, 0.75)], tone)
    return Surface(height, albedo)


def texture(name: str) -> np.ndarray:
    """Lit texture for a ground name: `grass`, `grass-autumn`, `beach-1`, `water-3`, ..."""
    parts = name.split("-")
    frame = int(parts[-1]) if parts[-1].isdigit() else 0
    season = next((p for p in parts if p in GRASS), "spring")
    if parts[0] == "grass":
        return shade(grass(season, frame))
    if parts[0] == "beach":
        return shade(beach(frame))
    if parts[0] == "water":
        return shade(water(frame))
    if parts[0] == "forest":
        return shade(forest(season))
    if parts[0] == "mountain":
        return shade(rock(int(parts[-1][1:]) if parts[-1].startswith("v") else 0))
    raise ValueError(f"no ground texture {name}")
