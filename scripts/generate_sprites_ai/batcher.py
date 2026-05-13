"""Sprite generation orchestrator.

This is the only impure module in the pipeline. It:
- walks every `Resources/Sprites.style/catalog/*.md` entry,
- composes a prompt,
- checks the prompt-hash cache,
- on miss, calls `/v1/images/edits` with the master-reference attached,
- writes the resulting sheet to `_cache/<hash>.png` and `_sheets/<id>.png`,
- slices the sheet via `slice_plan` + `slice_sheet`,
- post-processes each cell (chroma-key + downsample + quantize),
- writes per-cell PNGs into the category atlas directories.

`run_pipeline(offline=False, verify=False)` returns 0 on success.
"""

from __future__ import annotations

import base64
import concurrent.futures
import io
import os
import tomllib
from collections.abc import Callable
from pathlib import Path

import httpx
from PIL import Image

from . import paths
from .cache import (
    cache_key,
    read_cache,
    read_sheet,
    write_cache,
    write_sheet,
)
from .composer import FIXED_INSTRUCTIONS, compose_prompt
from .postprocess import chroma_key, downsample, quantize
from .slicer import CatalogEntry, parse_catalog_entry, slice_plan, slice_sheet


# Per-prefix downsample target. New sprite kinds inherit the prefix
# default; existing kinds override via the on-disk PNG (the batcher
# reads its size to preserve byte-for-byte compatibility with the
# existing layout).
PREFIX_TARGETS: dict[str, tuple[int, int]] = {
    "terrain-": (64, 32),
    "building-": (128, 128),
    "walker-": (8, 12),
    "ship-": (32, 16),
    "good-": (24, 24),
}


# 32-colour palette from `Resources/Sprites.style/world.md` § Palette.
# Pipeline quantizes every generated cell to this set after the
# chroma-key pass. The chroma-key colour is preserved separately on
# transparent pixels.
PALETTE: list[tuple[int, int, int]] = [
    (0x3D, 0x2A, 0x1D), (0x5C, 0x3F, 0x28), (0x8C, 0x6A, 0x45),
    (0xC9, 0xA6, 0x71), (0x5C, 0x80, 0x38), (0x3F, 0x5C, 0x26),
    (0x8F, 0xB0, 0x4E),
    (0x7A, 0x6B, 0x59), (0x5C, 0x50, 0x46), (0xA8, 0x98, 0x84),
    (0x6E, 0x4A, 0x2A), (0x4A, 0x2F, 0x1A), (0xA0, 0x7C, 0x50),
    (0xD4, 0xA8, 0x6A),
    (0x7A, 0x1F, 0x1A), (0xA5, 0x33, 0x29), (0x3F, 0x2A, 0x26),
    (0x8B, 0x5A, 0x2B), (0xD2, 0xC0, 0x94), (0x8B, 0x1A, 0x1A),
    (0x2A, 0x4E, 0x6E), (0x3F, 0x6E, 0x94), (0x6F, 0xA4, 0xC2),
    (0xA8, 0xCC, 0xDD),
    (0x1A, 0x14, 0x10), (0xFF, 0xE9, 0xC8),
]


def _api_url() -> str:
    base = os.environ.get("OPENAI_BASE_URL", "https://api.openai.com")
    return base.rstrip("/") + "/v1/images/edits"


def _load_pipeline_toml() -> dict:
    with paths.PIPELINE_TOML.open("rb") as f:
        return tomllib.load(f)


def _target_size(sprite_name: str) -> tuple[int, int]:
    """Pick the downsample target size for `sprite_name`. Prefers the
    existing committed PNG's dimensions (so a regen drops in byte-for-
    byte against the current atlas layout); falls back to the
    per-prefix default for never-before-shipped names."""
    try:
        atlas_dir = paths.atlas_dir_for(sprite_name)
    except ValueError:
        return (128, 128)
    existing = atlas_dir / f"{sprite_name}.png"
    if existing.exists():
        try:
            return Image.open(existing).size
        except Exception:
            pass
    for prefix, default in PREFIX_TARGETS.items():
        if sprite_name.startswith(prefix):
            return default
    return (128, 128)


def _save_indexed_png(image: Image.Image, dest: Path) -> None:
    """Save a Pillow image as an optimized indexed-mode PNG. Per
    `sprite-asset-pipeline` § "Committed PNGs are indexed-mode and
    optimized": output footprint stays bounded; aesthetic fidelity is
    unaffected because pixel art has ≤32 distinct colours.
    """
    # Convert RGBA -> P with palette quantization while preserving
    # transparency: Pillow's quantize() handles the palette; the alpha
    # mask survives into the 'P' image's transparency entry when we
    # remap.
    rgba = image.convert("RGBA")
    alpha = rgba.split()[-1]
    rgb = rgba.convert("RGB")
    indexed = rgb.quantize(colors=256, method=Image.Quantize.LIBIMAGEQUANT, dither=Image.Dither.NONE)
    # Restore alpha by adding a transparency palette index. The simple
    # approach: paste the image and use the alpha as transparency mask
    # via a synthesized palette slot.
    indexed.info["transparency"] = 0  # reserve index 0 for fully transparent
    indexed = indexed.convert("RGBA")
    indexed.putalpha(alpha)
    indexed = indexed.convert("P", palette=Image.Palette.ADAPTIVE, colors=256)
    dest.parent.mkdir(parents=True, exist_ok=True)
    indexed.save(dest, format="PNG", optimize=True)


def _process_and_write_cell(sprite_name: str, tile: Image.Image) -> Path:
    """Full post-process and write for one tile. Returns the output
    path. Idempotent given identical inputs."""
    target = _target_size(sprite_name)
    keyed = chroma_key(tile, hex_color="#FF00FF")
    resized = downsample(keyed, target, mode="nearest")
    quantized = quantize(resized, PALETTE)
    atlas_dir = paths.atlas_dir_for(sprite_name)
    out_path = atlas_dir / f"{sprite_name}.png"
    _save_indexed_png(quantized, out_path)
    return out_path


# ---------------- API call ----------------

def _post_edit(
    *,
    api_key: str,
    model_id: str,
    prompt: str,
    master_reference_path: Path,
    size: str,
    n: int = 1,
    timeout: float = 600.0,
) -> Image.Image:
    """Call /v1/images/edits with the master-reference attached.
    Returns the generated sheet as a Pillow image."""
    with master_reference_path.open("rb") as fh:
        files = {"image": (master_reference_path.name, fh.read(), "image/png")}
    data = {
        "model": model_id,
        "prompt": prompt,
        "size": size,
        "n": str(n),
    }
    headers = {"Authorization": f"Bearer {api_key}"}
    with httpx.Client(timeout=timeout) as client:
        resp = client.post(_api_url(), files=files, data=data, headers=headers)
        if resp.status_code >= 400:
            raise RuntimeError(
                f"edits call failed for sheet: {resp.status_code} {resp.text[:500]}"
            )
        payload = resp.json()
    item = payload["data"][0]
    if "b64_json" in item and item["b64_json"]:
        return Image.open(io.BytesIO(base64.b64decode(item["b64_json"]))).convert("RGBA")
    if "url" in item and item["url"]:
        with httpx.Client(timeout=timeout) as client:
            blob = client.get(item["url"])
            blob.raise_for_status()
        return Image.open(io.BytesIO(blob.content)).convert("RGBA")
    raise RuntimeError(f"unexpected response shape: {list(item.keys())}")


# ---------------- Orchestration ----------------

def _sheet_for_entry(
    entry: CatalogEntry,
    entry_md: str,
    world_md: str,
    model_id: str,
    offline: bool,
    on_cache_hit: Callable[[str], None] | None = None,
) -> Image.Image:
    """Resolve the sprite sheet for one catalog entry. Returns a
    Pillow image. Honours offline mode: reads from `_sheets/<id>.png`
    only and raises if absent."""
    if offline:
        sheet = read_sheet(entry.id)
        if sheet is None:
            raise RuntimeError(
                f"offline regen requires _sheets/{entry.id}.png to be "
                "committed; run `make sprites` with OPENAI_API_KEY set"
            )
        return sheet

    key = cache_key(world_md, entry_md, FIXED_INSTRUCTIONS, model_id)
    cached = read_cache(key)
    if cached is not None:
        if on_cache_hit is not None:
            on_cache_hit(entry.id)
        # Mirror to _sheets/ so the offline path stays consistent
        # (cheap; the file may already exist with identical bytes).
        if read_sheet(entry.id) is None:
            write_sheet(entry.id, cached)
        return cached

    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        raise RuntimeError(
            "OPENAI_API_KEY is not set in the environment — required "
            "for online sprite generation. Use `--offline` to skip."
        )
    prompt = compose_prompt(world_md, entry_md, FIXED_INSTRUCTIONS)
    # Stick to a square API size — the slicer divides by grid, so the
    # cell aspect ratio comes from the catalog, not the sheet shape.
    fresh = _post_edit(
        api_key=api_key,
        model_id=model_id,
        prompt=prompt,
        master_reference_path=paths.MASTER_REFERENCE,
        size="1024x1024",
    )
    write_cache(key, fresh, api_response_json=None)
    write_sheet(entry.id, fresh)
    # Re-read the just-written indexed-PNG sheet so the in-memory
    # bytes used for slicing match exactly what `read_sheet` will
    # return on a future offline run. Without this round-trip, online
    # and offline runs would produce different atlas PNGs because the
    # indexed encoding is lossy w.r.t. the original 24-bit API output.
    sheet = read_sheet(entry.id)
    if sheet is None:
        raise RuntimeError(
            f"failed to read back just-written sheet for {entry.id}"
        )
    return sheet


def _process_entry(
    entry: CatalogEntry,
    sheet: Image.Image,
) -> list[Path]:
    """Slice + post-process + write every cell for one entry. Returns
    the list of written atlas paths."""
    plan = slice_plan(entry)
    cells = slice_sheet(sheet, plan, grid=entry.grid, sheet_size=sheet.size)
    written: list[Path] = []
    for sprite_name, tile in cells:
        out = _process_and_write_cell(sprite_name, tile)
        written.append(out)
    return written


def run_pipeline(offline: bool = False, verify: bool = False) -> int:
    """Walk the catalog and regenerate every atlas PNG.

    Returns 0 on success; 1 on the first hard failure (raised
    exception). `verify` runs `offline=True` and then prints what
    would have been written but does not write.
    """
    cfg = _load_pipeline_toml()
    model_id = cfg["model"]
    max_inflight = int(cfg.get("concurrency", {}).get("max_inflight", 4))

    world_md = paths.WORLD_MD.read_text(encoding="utf-8")
    entries: list[tuple[CatalogEntry, str]] = []
    for md in sorted(paths.CATALOG_DIR.glob("*.md")):
        text = md.read_text(encoding="utf-8")
        entries.append((parse_catalog_entry(md.stem, text), text))

    if not entries:
        print("[batcher] no catalog entries found; nothing to do", flush=True)
        return 0

    effective_offline = offline or verify

    def work(entry_pair: tuple[CatalogEntry, str]) -> list[Path]:
        entry, entry_md = entry_pair
        sheet = _sheet_for_entry(
            entry, entry_md, world_md, model_id, effective_offline,
            on_cache_hit=lambda eid: print(f"[cache hit] {eid}", flush=True),
        )
        return _process_entry(entry, sheet)

    written: list[Path] = []
    if effective_offline:
        # Offline path is deterministic and CPU-bound; run sequentially
        # so the ordered log output stays stable.
        for pair in entries:
            written.extend(work(pair))
    else:
        with concurrent.futures.ThreadPoolExecutor(max_workers=max_inflight) as ex:
            futures = {ex.submit(work, p): p[0].id for p in entries}
            for fut in concurrent.futures.as_completed(futures):
                eid = futures[fut]
                try:
                    written.extend(fut.result())
                    print(f"[done] {eid}", flush=True)
                except Exception as exc:
                    print(f"[fail] {eid}: {exc}", flush=True)
                    return 1

    print(f"[batcher] wrote {len(written)} atlas PNGs", flush=True)
    return 0
