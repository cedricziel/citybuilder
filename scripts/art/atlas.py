"""Atlas routing and the indexed PNG writer shared by every art step."""

from __future__ import annotations

import os
import tempfile
from pathlib import Path

from PIL import Image

# Mirrors `SpriteAtlasRouting.atlasName(for:)` in CityRender2D.
PREFIXES = {
    "terrain-": "Terrain",
    "building-": "Buildings",
    "overlay-": "Buildings",
    "walker-": "Units",
    "ship-": "Units",
    "good-": "Icons",
}


def atlas_name(file_name: str) -> str:
    for prefix, atlas in PREFIXES.items():
        if file_name.startswith(prefix):
            return atlas
    raise ValueError(f"no atlas for sprite file {file_name}")


def atlas_path(resources: Path, file_name: str) -> Path:
    return resources / f"{atlas_name(file_name)}.atlas" / file_name


def save_indexed(image: Image.Image, dest: Path) -> None:
    """Optimized 256-colour indexed PNG, alpha kept as tRNS by libimagequant (spec: Committed PNGs
    are indexed-mode and optimized). Written beside `dest` and renamed over it, so a reader never
    sees a half-written file."""
    indexed = image.convert("RGBA").quantize(colors=256, method=Image.Quantize.LIBIMAGEQUANT, dither=Image.Dither.NONE)
    dest.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=dest.parent, prefix=f".{dest.name}.", delete=False) as tmp:
        tmp_path = Path(tmp.name)
    try:
        indexed.save(tmp_path, format="PNG", optimize=True)
        tmp_path.chmod(0o644)
        os.replace(tmp_path, dest)
    finally:
        tmp_path.unlink(missing_ok=True)
