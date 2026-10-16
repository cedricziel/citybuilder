"""Painterly, lit ground textures for the terrain tiles (capability `iso-art-kit`, design D6).

Every texture lives in tile space (u, v) and repeats with period 1 in both, so any two tiles join
without a seam, whatever they sit next to. Each terrain is a small heightfield in metres (a tile is
4 m across) and an albedo, lit like the IsoKit rig: a warm sun from the upper left and a cool sky.
Noise comes from filtering white noise in the frequency domain, which is periodic by construction.
"""

from __future__ import annotations

import base64
import hashlib
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
    # Hash the whole name: its raw bytes mod 2**63 kept only the first 8 characters, so
    # `grass-blades-0` and `grass-blades-1` (and every rock variant) drew the same noise.
    rng = np.random.default_rng(int.from_bytes(hashlib.sha256(seed.encode()).digest()[:8], "little"))
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


def window() -> np.ndarray:
    """(sin pi u * sin pi v)^2: zero on every tile edge, so what it scales never reaches a neighbour."""
    uu, vv = _grid()
    return (np.sin(np.pi * uu) * np.sin(np.pi * vv)) ** 2


GRASS_VARIANTS = 4


def framed(seed: str, frame: int, wavelength: float, sharp: float = 2.0) -> np.ndarray:
    """Noise that changes from frame to frame only inside the tile: its edges always hold frame 0,
    so an animated tile joins neighbours in any frame and the static transitions baked from frame 0."""
    still = noise(f"{seed}-0", wavelength, sharp)
    return still if frame == 0 else still + window() * (noise(f"{seed}-{frame}", wavelength, sharp) - still)


def grass(season: str = "spring", frame: int = 0, variant: int = 0) -> Surface:
    """Meadow: clumps and blade stipple that sways between frames. Broad light and dark patches come
    from the renderer's macro field, across tiles, so here they stay faint. Variants add their own
    clumps inside a window that vanishes on the tile edges, so any variant joins any other."""
    broad, clumps = noise("grass-broad", 0.7), noise("grass-clumps", 0.18)
    if variant:
        own = window()
        broad = broad + own * noise(f"grass-broad-v{variant}", 0.45)
        clumps = clumps + own * noise(f"grass-clumps-v{variant}", 0.18)
    blades = framed("grass-blades", frame, 0.035, sharp=1.0)
    tone = 0.5 + 0.1 * broad + 0.18 * clumps + 0.1 * blades + (0.22 if season == "winter" else 0)
    albedo = mix(GRASS[season], tone)
    height = 0.05 * clumps + 0.015 * blades
    return Surface(height, albedo)


def beach(frame: int = 0) -> Surface:
    """Sand with wind ripples, darker damp patches and the odd pebble."""
    u = np.linspace(0, 1, SIZE, endpoint=False)
    uu, vv = np.meshgrid(u, u, indexing="ij")
    ripples = np.sin(2 * np.pi * (6 * uu + 9 * vv) + 1.5 * noise("sand-warp", 0.3))
    damp = noise("sand-damp", 0.6)
    tone = 0.55 + 0.25 * damp + 0.05 * ripples + 0.06 * framed("sand-grain", frame, 0.03, sharp=1.0)
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
    def swell(phase: float) -> np.ndarray:
        return sum(amp * np.sin(2 * np.pi * (ku * uu + kv * vv) + warp - speed * phase) for (ku, kv), amp, speed in waves)

    # The swell moves inside the tile only: its edges hold frame 0, like every animated ground, so
    # neighbours in other frames and the static shore tiles (baked from frame 0) always join.
    height = swell(0) + window() * (swell(phase) - swell(0))
    height = height + 0.006 * framed("water-chop", frame % frames, 0.06)
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
    "spring": [(0.26, 0.44, 0.17), (0.33, 0.52, 0.19), (0.42, 0.56, 0.21), (0.48, 0.58, 0.24), (0.24, 0.40, 0.22)],
    "autumn": [(0.58, 0.44, 0.20), (0.64, 0.54, 0.26), (0.50, 0.34, 0.18), (0.54, 0.50, 0.26), (0.38, 0.44, 0.22)],
}
CONIFER = (0.18, 0.34, 0.20)
FLOOR = (0.28, 0.30, 0.15)
FLOOR_HEIGHT = -0.15
TWIGS = (0.46, 0.42, 0.38)
SNOW = (0.84, 0.90, 0.98)  # cool, so the warm sun leaves it white rather than cream


def forest(season: str = "spring") -> Surface:
    """A loose canopy of 26 crowns per tile in five tones and three sizes, scattered so the repeat is
    hard to see, with small clearings where the floor shows. Three in ten are conifers. Relief stays shallow so cast shadows
    model the crowns without drowning the tile. In winter the broadleaf crowns are bare: a grey
    haze of twigs painted onto the snow with no relief of its own, so it casts no shadow; the
    conifers keep their needles and carry snow on their sunlit side."""
    rng = np.random.default_rng(11)
    uu, vv = _grid()
    winter = season == "winter"
    height = np.full((SIZE, SIZE), FLOOR_HEIGHT)
    albedo = np.empty((SIZE, SIZE, 3))
    albedo[:] = SNOW if winter else FLOOR
    albedo *= (1 + 0.12 * noise("forest-floor", 0.1))[..., None]
    leaves = noise("forest-leaves", 0.03, sharp=1.0)
    lace = np.clip(1 - np.abs(noise("forest-twigs", 0.02, sharp=0.5)) * 2, 0, 1)
    crowns = [(rng.random(), rng.random(), rng.choice([0.07, 0.11, 0.16]), rng.random() < 0.3) for _ in range(26)]
    for cu, cv, radius, conifer in sorted(crowns, key=lambda c: c[2]):
        tone = FOLIAGE["autumn" if season == "autumn" else "spring"][rng.integers(5)]
        shade = 0.88 + 0.24 * rng.random()
        lift = 0.1 * rng.random()
        d = _wrapped_distance(uu, vv, cu, cv) / radius
        if winter and not conifer:
            on_floor = height <= FLOOR_HEIGHT  # never over a crown painted before
            twigs = (d < 1) * on_floor * (0.35 + 0.45 * lace) * (1 - d.clip(0, 1) ** 2)
            albedo = albedo * (1 - twigs[..., None]) + np.array(TWIGS) * twigs[..., None]
            continue
        crown = np.sqrt(np.clip(1 - d**2, 0, 1)) * min(radius * TILE_METRES, 0.45) + lift
        inside = (d < 1) & (crown > height)
        height = np.where(inside, crown, height)
        colour = np.array(CONIFER if conifer else tone) * shade
        albedo[inside] = colour * (1 + 0.22 * leaves[inside, None])
        if winter:
            snowy = inside & (d < 0.8) & ((uu - cu + 0.5) % 1 - 0.5 < 0.03) & (leaves > -0.3)
            albedo[snowy] = 0.4 * albedo[snowy] + 0.6 * np.array(SNOW)
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
    variant = next((int(p[1:]) for p in parts if p[:1] == "v" and p[1:].isdigit()), 0)
    if parts[0] == "grass":
        return shade(grass(season, frame, variant))
    if parts[0] == "beach":
        return shade(beach(frame))
    if parts[0] == "water":
        return shade(water(frame))
    if parts[0] == "forest":
        return shade(forest(season))
    if parts[0] == "mountain":
        return shade(rock(variant))
    raise ValueError(f"no ground texture {name}")
