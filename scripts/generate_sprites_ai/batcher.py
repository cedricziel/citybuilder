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
import re
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


def _process_and_write_cell(
    sprite_name: str,
    tile: Image.Image,
    output_dir_resolver: Callable[[str], Path] | None = None,
) -> Path:
    """Full post-process and write for one tile. Returns the output
    path. Idempotent given identical inputs.

    `output_dir_resolver` lets verify mode route writes into a temp
    directory without redirecting `paths.atlas_dir_for` globally — so
    `_target_size` keeps reading the committed PNG dimensions from
    the real atlas dirs."""
    target = _target_size(sprite_name)
    keyed = chroma_key(tile, hex_color="#FF00FF")
    resized = downsample(keyed, target, mode="nearest")
    quantized = quantize(resized, PALETTE)
    resolver = output_dir_resolver or paths.atlas_dir_for
    out_path = resolver(sprite_name) / f"{sprite_name}.png"
    _save_indexed_png(quantized, out_path)
    return out_path


# ---------------- API call ----------------

def _is_two_pass(entry: CatalogEntry) -> bool:
    """Check the entry's front-matter for the two-pass opt-in. The
    parser stores all front-matter values as strings; we accept any
    truthy variant a contributor might write."""
    raw = entry.front_matter.get("two-pass", "").strip().lower()
    return raw in {"true", "yes", "1"}


def _operational_cells(entry: CatalogEntry) -> set[tuple[int, int]]:
    """The set of (row, col) cells that map to operational animation
    frames — those are the cells pass-2 regenerates against the
    pass-1 base."""
    return {
        coord
        for coord, name in entry.cells.items()
        if "-operational-" in name
    }


def _generate_sheet(
    *,
    entry: CatalogEntry,
    entry_md: str,
    world_md: str,
    api_key: str,
    model_id: str,
) -> Image.Image:
    """Run the catalog entry's generation flow (single-pass by default,
    two-pass when opted in via front matter). Returns a single
    composed Pillow image at 1024×1024."""
    if not _is_two_pass(entry):
        prompt = compose_prompt(world_md, entry_md, FIXED_INSTRUCTIONS)
        return _post_edit(
            api_key=api_key,
            model_id=model_id,
            prompt=prompt,
            master_reference_path=paths.MASTER_REFERENCE,
            size="1024x1024",
        )

    # Two-pass: pass-1 generates design + construction with operational
    # cells declared as spare; pass-2 regenerates operational cells
    # against the pass-1 base cell as reference. Per design.md §D7.
    op_cells = _operational_cells(entry)
    pass1_md = _entry_md_with_operational_spared(entry_md)
    pass1_prompt = compose_prompt(world_md, pass1_md, FIXED_INSTRUCTIONS)
    pass1_sheet = _post_edit(
        api_key=api_key,
        model_id=model_id,
        prompt=pass1_prompt,
        master_reference_path=paths.MASTER_REFERENCE,
        size="1024x1024",
    )

    # Extract the pass-1 base cell (canonical position is (0, 0)).
    cols, rows = entry.grid
    if cols <= 0 or rows <= 0 or not op_cells:
        # Defensive: no operational cells to second-pass; treat as
        # single-pass output.
        return pass1_sheet
    pass1_w, pass1_h = pass1_sheet.size
    cell_w = pass1_w // cols
    cell_h = pass1_h // rows
    base_tile = pass1_sheet.crop((0, 0, cell_w, cell_h))

    # Pass-2: regenerate operational frames using the pass-1 base as
    # the style anchor. Saved to a tempfile so the existing
    # `_post_edit` multipart helper can attach it without reshaping.
    import tempfile
    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as fh:
        base_tile_path = Path(fh.name)
    try:
        base_tile.save(base_tile_path, format="PNG")
        pass2_md = _entry_md_with_only_operational(entry_md)
        pass2_prompt = compose_prompt(world_md, pass2_md, FIXED_INSTRUCTIONS)
        pass2_sheet = _post_edit(
            api_key=api_key,
            model_id=model_id,
            prompt=pass2_prompt,
            master_reference_path=base_tile_path,
            size="1024x1024",
        )
    finally:
        try:
            base_tile_path.unlink()
        except FileNotFoundError:
            pass

    # Composite: copy operational cells from pass-2 sheet into pass-1
    # sheet at their declared positions. Pass-1 keeps the design +
    # construction stages; pass-2 contributes the operational frames.
    composed = pass1_sheet.copy()
    for (row, col) in op_cells:
        left = col * cell_w
        upper = row * cell_h
        op_tile = pass2_sheet.crop((left, upper, left + cell_w, upper + cell_h))
        composed.paste(op_tile, (left, upper))
    return composed


def _entry_md_with_operational_spared(entry_md: str) -> str:
    """Rewrite Sheet section assignments that look like
    `building-x-operational-N` to `spare` so pass-1 doesn't waste
    pixels on cells pass-2 will overwrite anyway. Keeps the front
    matter intact (so the cache key picked up the mode)."""
    out_lines: list[str] = []
    for line in entry_md.splitlines():
        if "operational-" in line and "spare" not in line:
            # Replace ``:`<sprite-operational-X>`` with ``: spare``.
            replaced = re.sub(
                r":\s*`[^`]*-operational-\d+`",
                ": spare",
                line,
            )
            out_lines.append(replaced)
        else:
            out_lines.append(line)
    return "\n".join(out_lines)


def _entry_md_with_only_operational(entry_md: str) -> str:
    """Mirror image of the above: every non-operational, non-spare
    cell becomes spare so pass-2 focuses on operational frames."""
    out_lines: list[str] = []
    for line in entry_md.splitlines():
        # Match cell-assignment lines: `- (r, c): `name``.
        m = re.search(r":\s*`([^`]+)`", line)
        if m and "-operational-" not in m.group(1):
            replaced = re.sub(r":\s*`[^`]+`", ": spare", line)
            out_lines.append(replaced)
        else:
            out_lines.append(line)
    return "\n".join(out_lines)


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
    fresh = _generate_sheet(
        entry=entry,
        entry_md=entry_md,
        world_md=world_md,
        api_key=api_key,
        model_id=model_id,
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
    output_dir_resolver: Callable[[str], Path] | None = None,
) -> list[Path]:
    """Slice + post-process + write every cell for one entry. Returns
    the list of written atlas paths."""
    plan = slice_plan(entry)
    cells = slice_sheet(sheet, plan, grid=entry.grid, sheet_size=sheet.size)
    written: list[Path] = []
    for sprite_name, tile in cells:
        out = _process_and_write_cell(sprite_name, tile, output_dir_resolver)
        written.append(out)
    return written


def _diff_against_committed(written: list[Path]) -> list[Path]:
    """Return the subset of `written` whose bytes diverge from the
    on-disk PNG already at that path (read before this run started).
    Used by `--verify`; assumes the caller invoked the pipeline against
    a temp output directory whose subpaths mirror the real atlas dirs.
    """
    diffs: list[Path] = []
    for path in written:
        # Reconstruct the committed path: ATLAS_DIRS[<prefix>] / <stem>.png
        name = path.stem
        try:
            committed = paths.atlas_dir_for(name) / path.name
        except ValueError:
            continue
        if not committed.exists():
            diffs.append(path)
            continue
        if path.read_bytes() != committed.read_bytes():
            diffs.append(path)
    return diffs


def run_pipeline(offline: bool = False, verify: bool = False) -> int:
    """Walk the catalog and regenerate every atlas PNG.

    Returns 0 on success; 1 on the first hard failure or, in
    `--verify` mode, on any byte mismatch against the committed
    atlas PNGs.

    `verify` redirects atlas writes into a temp directory (so the
    working tree is never mutated), runs the pipeline offline against
    the committed `_sheets/`, and compares the produced bytes to the
    committed atlas PNGs. Non-zero exit on any divergence. Mirrors
    `make sprites-verify` for CI.
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
    output_resolver: Callable[[str], Path] | None = None
    temp_root: Path | None = None
    if verify:
        import tempfile
        temp_root = Path(tempfile.mkdtemp(prefix="sprites-verify-"))
        # Route writes through a temp output dir whose subpaths mirror
        # the real atlas dir layout. `_target_size` keeps reading from
        # the real atlas dirs (via the unmodified `paths.atlas_dir_for`).
        def _resolver(name: str) -> Path:
            real = paths.atlas_dir_for(name)
            return temp_root / real.name
        output_resolver = _resolver

    def work(entry_pair: tuple[CatalogEntry, str]) -> list[Path]:
        entry, entry_md = entry_pair
        sheet = _sheet_for_entry(
            entry, entry_md, world_md, model_id, effective_offline,
            on_cache_hit=lambda eid: print(f"[cache hit] {eid}", flush=True),
        )
        return _process_entry(entry, sheet, output_dir_resolver=output_resolver)

    try:
        written: list[Path] = []
        if effective_offline:
            # Offline path is deterministic and CPU-bound; run
            # sequentially so the ordered log output stays stable.
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

        if verify:
            diffs = _diff_against_committed(written)
            if diffs:
                print(
                    f"[verify] {len(diffs)} atlas PNG(s) differ from "
                    "the committed bytes — offline regen is not "
                    "reproducing the catalog. The committed catalog "
                    "and committed sheets must produce byte-identical "
                    "atlas PNGs.",
                    flush=True,
                )
                for d in diffs[:20]:
                    print(f"  - {d.name}", flush=True)
                if len(diffs) > 20:
                    print(f"  … and {len(diffs) - 20} more", flush=True)
                return 1
            print(f"[verify] {len(written)} atlas PNGs match committed", flush=True)
            return 0

        print(f"[batcher] wrote {len(written)} atlas PNGs", flush=True)
        return 0
    finally:
        if temp_root is not None and temp_root.exists():
            import shutil
            shutil.rmtree(temp_root, ignore_errors=True)
