"""Pure path-resolution helpers. Discovers project paths relative to
this module's location — no environment variables, no CWD reads.
"""

from __future__ import annotations

from pathlib import Path

# scripts/generate_sprites_ai/paths.py -> scripts/generate_sprites_ai
# -> scripts -> repo root
REPO_ROOT = Path(__file__).resolve().parent.parent.parent
STYLE_DIR = REPO_ROOT / "Resources" / "Sprites.style"
CATALOG_DIR = STYLE_DIR / "catalog"
SHEETS_DIR = STYLE_DIR / "_sheets"
CACHE_DIR = STYLE_DIR / "_cache"
WORLD_MD = STYLE_DIR / "world.md"
PIPELINE_TOML = STYLE_DIR / "pipeline.toml"
MASTER_REFERENCE = STYLE_DIR / "master-reference.png"

ATLAS_DIRS = {
    "terrain-": REPO_ROOT / "Resources" / "Terrain.atlas",
    "building-": REPO_ROOT / "Resources" / "Buildings.atlas",
    "walker-": REPO_ROOT / "Resources" / "Units.atlas",
    "ship-": REPO_ROOT / "Resources" / "Units.atlas",
    "good-": REPO_ROOT / "Resources" / "Icons.atlas",
}


def atlas_dir_for(name: str) -> Path:
    """Route a sprite name to its category atlas directory by prefix.
    Mirrors `SpriteAtlasRouting.atlasName(for:)` in the Swift side.
    """
    for prefix, directory in ATLAS_DIRS.items():
        if name.startswith(prefix):
            return directory
    raise ValueError(f"no atlas mapping for sprite name: {name}")
