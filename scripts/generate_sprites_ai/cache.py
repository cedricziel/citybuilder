"""Prompt-hash cache for the AI sprite pipeline.

Cache key = sha256(world.md + entry.md + fixed_instructions + model_id).
Storage: `Resources/Sprites.style/_cache/<hash>.png` + `<hash>.json`.

The cache is gitignored — it speeds up local iteration. The
authoritative source-of-truth for offline regen is
`Resources/Sprites.style/_sheets/<entry_id>.png` (committed).
"""

from __future__ import annotations

import hashlib
import json
from io import BytesIO
from pathlib import Path

from PIL import Image

from . import paths


# Test hook: tests set this to redirect cache I/O away from the real
# repo directory. Production code leaves it at None.
CACHE_DIR_OVERRIDE: Path | None = None


def _cache_dir() -> Path:
    return CACHE_DIR_OVERRIDE if CACHE_DIR_OVERRIDE is not None else paths.CACHE_DIR


def cache_key(
    world_md: str,
    entry_md: str,
    fixed_instructions: str,
    model_id: str,
) -> str:
    """Compute the cache key for one catalog entry.

    Pure function. SHA-256 over the deterministic byte concatenation
    of every input that should invalidate the cache. A null byte
    separates fields so a delimiter collision (e.g., world.md ending
    in the same prefix as entry.md beginning) can't produce a hash
    collision.
    """
    h = hashlib.sha256()
    for component in (world_md, entry_md, fixed_instructions, model_id):
        h.update(component.encode("utf-8"))
        h.update(b"\x00")
    return h.hexdigest()


def read_cache(key: str) -> Image.Image | None:
    """Return the cached PIL image for this key, or None on miss."""
    png_path = _cache_dir() / f"{key}.png"
    if not png_path.exists():
        return None
    with png_path.open("rb") as f:
        return Image.open(BytesIO(f.read())).convert("RGBA")


def _save_indexed(image: Image.Image, dest: Path) -> None:
    """Save a Pillow image as an optimized 256-colour indexed PNG.
    Per `sprite-asset-pipeline` § "Committed PNGs are indexed-mode and
    optimized": every committed binary stays well under 1 MB and the
    repo clone footprint stays bounded. Used by both `write_cache`
    (local convenience) and `write_sheet` (committed source-of-truth)
    so both round-trip the same pixel set."""
    rgba = image.convert("RGBA")
    rgb = rgba.convert("RGB")
    indexed = rgb.quantize(
        colors=256,
        method=Image.Quantize.LIBIMAGEQUANT,
        dither=Image.Dither.NONE,
    )
    dest.parent.mkdir(parents=True, exist_ok=True)
    indexed.save(dest, format="PNG", optimize=True)


def write_cache(
    key: str,
    image: Image.Image,
    api_response_json: dict | None = None,
) -> None:
    """Write the cached image and (optional) raw API response to the
    cache directory. Creates the directory if needed."""
    cache_dir = _cache_dir()
    cache_dir.mkdir(parents=True, exist_ok=True)
    _save_indexed(image, cache_dir / f"{key}.png")
    if api_response_json is not None:
        (cache_dir / f"{key}.json").write_text(
            json.dumps(api_response_json, sort_keys=True),
            encoding="utf-8",
        )


# Test hook for the sheet store too: redirected to tmp_path in tests.
SHEETS_DIR_OVERRIDE: Path | None = None


def _sheets_dir() -> Path:
    return SHEETS_DIR_OVERRIDE if SHEETS_DIR_OVERRIDE is not None else paths.SHEETS_DIR


def read_sheet(entry_id: str) -> Image.Image | None:
    """Return the committed sheet for this entry id, or None if
    absent. Used by `make sprites --offline`."""
    png_path = _sheets_dir() / f"{entry_id}.png"
    if not png_path.exists():
        return None
    with png_path.open("rb") as f:
        return Image.open(BytesIO(f.read())).convert("RGBA")


def write_sheet(entry_id: str, image: Image.Image) -> None:
    """Write the committed sheet for this entry id. Pipeline writes
    here on every online cache miss so that offline regen reproduces
    the same atlas PNGs. Encoded as indexed PNG per the
    `sprite-asset-pipeline` "Committed PNGs are indexed-mode and
    optimized" requirement."""
    sheets_dir = _sheets_dir()
    sheets_dir.mkdir(parents=True, exist_ok=True)
    _save_indexed(image, sheets_dir / f"{entry_id}.png")
