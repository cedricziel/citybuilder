"""Atlas routing and the indexed PNG writer shared by every art step."""

from __future__ import annotations

import os
import tempfile
from pathlib import Path

from PIL import Image

# Mirrors `SpriteAtlasRouting.kitAtlasName` in CityRender2D. Every art-kit render lives here:
# SpriteKit filters a whole atlas page with one mode, and kit art is linear while the legacy pixel
# art in the other atlases stays nearest (design D7). Every raw render, terrain transitions
# included, comes from a migrated brief, so its stem must be in
# `TextureFiltering.kitRenderedStems`; the CityRender2D test "every committed atlas PNG sits in
# the atlas its name routes to" fails otherwise.
KIT_ATLAS = "Kit"


def kit_path(resources: Path, file_name: str) -> Path:
    return resources / f"{KIT_ATLAS}.atlas" / file_name


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
