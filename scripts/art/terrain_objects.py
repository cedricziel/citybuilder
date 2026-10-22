"""Terrain object sprites as SVG sources (change `terrain-v2`, design D5): tree clumps for now.

`art.flora` ray-casts each object at @2x on the CPU; the result enters the SVG step
as an embedded image, so `art.svg_sprites` renders both scales like every other terrain sprite.
Ray-casting takes seconds per sprite, so renders are cached under `.build/art/objects`, keyed by
the sprite name and the source of every module that shapes it.
"""

from __future__ import annotations

import base64
import hashlib
import io
import os
from pathlib import Path

import numpy as np
from PIL import Image

from art import flora, ground

CACHE = Path(os.environ.get("ART_OBJECT_CACHE", Path(__file__).resolve().parents[2] / ".build" / "art" / "objects"))
VARIANTS = 4
TREES = ("single", "sparse", "medium", "dense")
TREE_SEASONS = ("", "autumn", "winter")


def names() -> list[str]:
    """Every object sprite: `terrain-<kind>-<density>[-<season>][-v<n>]`."""
    out = []
    for kind, densities, seasons in (("forest", TREES, TREE_SEASONS),):
        for density in densities:
            for season in seasons:
                for variant in range(VARIANTS):
                    out.append("-".join(filter(None, ["terrain", kind, density, season, f"v{variant}" if variant else ""])))
    return out


def parse(name: str) -> tuple[str, str, str, int]:
    parts = name.split("-")[1:]
    kind, density = parts[0], parts[1]
    variant = int(parts[-1][1:]) if parts[-1].startswith("v") else 0
    season = next((p for p in parts[2:] if p in ("autumn", "winter")), "spring")
    return kind, density, season, variant


def _fingerprint() -> str:
    digest = hashlib.sha256()
    for module in (flora, ground):
        digest.update(Path(module.__file__).read_bytes())
    return digest.hexdigest()[:16]


def render(name: str) -> np.ndarray:
    """Straight-alpha RGBA in 0..1 at @2x, from the cache when the sources have not changed."""
    path = CACHE / f"{name}-{_fingerprint()}.npy"
    if path.exists():
        return np.load(path)
    kind, density, season, variant = parse(name)
    image = flora.sprite(density, variant, season)
    CACHE.mkdir(parents=True, exist_ok=True)
    np.save(path, image.astype(np.float32))
    return image


def svg(name: str) -> str:
    """The sprite as an SVG of its @1x size holding the @2x render."""
    rgba = render(name)
    image = Image.fromarray((np.clip(rgba, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA")
    buffer = io.BytesIO()
    image.save(buffer, format="PNG", optimize=True)
    data = base64.b64encode(buffer.getvalue()).decode()
    w, h = flora.WIDTH, flora.HEIGHT
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">\n'
        f'<image width="{w}" height="{h}" preserveAspectRatio="none" href="data:image/png;base64,{data}"/>\n</svg>\n'
    )


def sources(wanted: set[str] | None = None) -> dict[str, str]:
    """Every object sprite, or only the `wanted` ones: each costs seconds the first time."""
    return {name: svg(name) for name in names() if wanted is None or name in wanted}
