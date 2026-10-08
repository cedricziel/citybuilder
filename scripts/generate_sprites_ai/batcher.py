"""Sprite generation orchestrator.

This is the only impure module in the pipeline. It:
- walks every `Resources/Sprites.style/catalog/*.md` entry,
- builds a slice plan (the list of atlas filenames the entry produces),
- for each atlas filename, makes ONE `/v1/images/edits` API call
  asking for that specific sprite on a transparent background,
- writes each raw API result to `_cache/<hash>.png` and
  `_sheets/<sprite-name>.png`,
- post-processes each (threshold alpha to binary, downsample, quantize),
- writes per-sprite PNGs into the category atlas directories.

The original design called one API per catalog entry and sliced the
resulting "sheet" into per-cell tiles. That turned out to be wrong:
the image model doesn't honour cell-grid layouts and composes one
centred image regardless of the prompt's "N×M grid" language, so the
slicer ended up carving a single building's silhouette into per-cell
junk. One API call per atlas filename is more expensive (24 → 126
calls per regen) but produces predictable, reviewable output.

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

from . import cache as _cache_mod
from . import paths, procedural
from .cache import (
    cache_key,
    read_cache,
    read_sheet,
    write_cache,
    write_sheet,
)
from .composer import compose_single_sprite_prompt
from .postprocess import diamond_fit, downsample, quantize, threshold_alpha
from .slicer import CatalogEntry, parse_catalog_entry, slice_plan


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
# Pipeline quantizes every generated cell to this set. Transparent
# pixels (alpha=0) are preserved through the quantize step — the
# RGB-snap to nearest palette entry only affects opaque pixels'
# colours, never their alpha.
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
    """Save a Pillow image as an optimized indexed-mode PNG with
    alpha preserved. Per `sprite-asset-pipeline` § "Committed PNGs
    are indexed-mode and optimized": output footprint stays bounded;
    aesthetic fidelity is unaffected because pixel art has ≤32
    distinct colours.

    Uses libimagequant's RGBA-aware quantizer, which produces a
    P-mode image with a tRNS chunk encoding per-palette-index alpha.
    Pillow's other quantize chains (e.g., split alpha → RGB →
    quantize → re-paste) silently drop the per-pixel alpha at the
    final RGBA-to-P conversion.
    """
    rgba = image.convert("RGBA")
    indexed = rgba.quantize(
        colors=256,
        method=Image.Quantize.LIBIMAGEQUANT,
        dither=Image.Dither.NONE,
    )
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
    # Threshold soft model alpha to binary BEFORE downsampling so the
    # silhouette edges stay crisp at the canonical pixel-art scale.
    binarized = threshold_alpha(tile, threshold=128)
    resized = downsample(binarized, target, mode="nearest")
    quantized = quantize(resized, PALETTE)
    if sprite_name.startswith("terrain-"):
        quantized = diamond_fit(quantized)
    resolver = output_dir_resolver or paths.atlas_dir_for
    out_path = resolver(sprite_name) / f"{sprite_name}.png"
    _save_indexed_png(quantized, out_path)
    return out_path


# ---------------- Role descriptions ----------------

# Matches a catalog Sheet-section line like:
#   - (0, 1): `building-house-constructing-0` — foundation stage ...
# Captures the sprite name and the trailing role description after `—`
# / `--`. The description gets fed into the per-sprite prompt so the
# model knows whether it's painting a base, a construction stage, an
# operational frame, an art variant, etc.
_ROLE_LINE_RE = re.compile(
    r":\s*`([^`]+)`\s*(?:—|--)\s*(.+?)\s*$",
    re.MULTILINE,
)


def build_role_map(entry_md: str) -> dict[str, str]:
    """Extract per-sprite role descriptions from an entry's Sheet
    section. Falls back to "the canonical sprite for this kind" when a
    cell line has no trailing description."""
    roles: dict[str, str] = {}
    for match in _ROLE_LINE_RE.finditer(entry_md):
        name = match.group(1).strip()
        desc = match.group(2).strip()
        if name and name != "spare":
            roles[name] = desc
    return roles


def role_for(sprite_name: str, role_map: dict[str, str]) -> str:
    """Return the role description for a sprite name. Prefers the
    catalog's own per-cell description when present; otherwise falls
    back to a derived description from the sprite's filename pattern."""
    if sprite_name in role_map:
        return role_map[sprite_name]
    # Pattern-based fallback for sprite names that don't carry an
    # explicit per-cell line (rare; usually means the catalog file
    # is using a compact format).
    if sprite_name.startswith("walker-"):
        parts = sprite_name.split("-")
        return f"walker unit, facing {parts[1]}, walk-cycle frame {parts[2]}"
    if sprite_name.startswith("ship-"):
        parts = sprite_name.split("-")
        return f"sailing ship, facing {parts[1]}, sail-luff frame {parts[2]}"
    if sprite_name.startswith("good-"):
        return f"goods icon for `{sprite_name[len('good-'):]}` (UI element)"
    return "the canonical sprite for this kind"


# ---------------- Generation ----------------


def _is_two_pass(entry: CatalogEntry) -> bool:
    """Check the entry's front-matter for the two-pass opt-in. The
    parser stores all front-matter values as strings; we accept any
    truthy variant a contributor might write."""
    raw = entry.front_matter.get("two-pass", "").strip().lower()
    return raw in {"true", "yes", "1"}


def _is_operational_frame(sprite_name: str) -> bool:
    return "-operational-" in sprite_name


def _base_name_for_kind(sprite_name: str) -> str:
    """Strip the `-operational-N` suffix from a sprite name to get its
    base sprite's filename. Used by two-pass mode to identify which
    already-generated base sprite anchors the operational-frame call.

        building-sawmill-operational-2  ->  building-sawmill
        building-port-n-operational-0   ->  building-port-n
    """
    return re.sub(r"-operational-\d+$", "", sprite_name)


def _generate_single_sprite(
    *,
    sprite_name: str,
    role: str,
    entry: CatalogEntry,
    entry_md: str,
    world_md: str,
    api_key: str,
    model_id: str,
) -> Image.Image:
    """Produce one sprite PNG via the API. Returns a Pillow image.

    Honours the entry's `two-pass: true` front-matter: when set, base
    and construction sprites still anchor on `master-reference.png`,
    but operational-frame sprites anchor on the already-committed base
    sprite (`_sheets/<base>.png`). Coherence between base and animation
    cells comes from sharing the same anchor image rather than from
    inferring it across a multi-cell sheet."""
    prompt = compose_single_sprite_prompt(
        world_md=world_md,
        entry_md=entry_md,
        sprite_name=sprite_name,
        role_description=role,
    )

    anchor_path = paths.MASTER_REFERENCE
    if _is_two_pass(entry) and _is_operational_frame(sprite_name):
        base = _base_name_for_kind(sprite_name)
        # Use cache._sheets_dir() (not paths.SHEETS_DIR) so tests can
        # redirect both sheet I/O paths through one override hook.
        base_sheet = _cache_mod._sheets_dir() / f"{base}.png"
        if base_sheet.exists():
            anchor_path = base_sheet

    return _post_edit(
        api_key=api_key,
        model_id=model_id,
        prompt=prompt,
        master_reference_path=anchor_path,
        size="1024x1024",
    )


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
        # Real per-pixel alpha out of the model. Replaces the
        # legacy magenta chroma-key path (which lived through one
        # short-lived attempt at this pipeline).
        "background": "transparent",
        "output_format": "png",
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

# Magic constant: empty fixed-instructions string passed into the
# cache_key call. Pre-rewrite, the FIXED_INSTRUCTIONS block from
# composer.py was hashed into every cache key. Now the per-sprite
# prompt embeds its own SINGLE_SPRITE_INSTRUCTIONS plus a sprite-name
# discriminator, both of which live in entry_md (via the prompt-build
# call) anyway. Keeping the parameter for back-compat with test
# fixtures.
_LEGACY_FIXED_INSTRUCTIONS = ""


def _sprite_for_atlas_name(
    sprite_name: str,
    role: str,
    entry: CatalogEntry,
    entry_md: str,
    world_md: str,
    model_id: str,
    offline: bool,
    on_cache_hit: Callable[[str], None] | None = None,
) -> Image.Image:
    """Resolve one sprite's raw 1024×1024 RGBA-with-alpha image.

    Offline mode reads from `_sheets/<sprite-name>.png` and raises if
    absent. Online mode hits the cache first, then the API, writing
    the result to both `_cache/<hash>.png` and `_sheets/<sprite>.png`.
    The just-written PNG is re-read so the in-memory bytes used for
    post-processing match exactly what `read_sheet` will return on a
    future offline run (indexed encoding is lossy w.r.t. the model's
    24-bit RGBA output; the round-trip collapses online and offline
    onto a single deterministic input).
    """
    if _is_procedural(entry) and not offline:
        write_sheet(sprite_name, procedural.render_sheet(sprite_name))
        return _read_back(sprite_name)

    if _is_derived_operational(entry, sprite_name) and not offline:
        write_sheet(sprite_name, _derived_sheet(entry, sprite_name))
        return _read_back(sprite_name)

    if offline:
        sheet = read_sheet(sprite_name)
        if sheet is None:
            raise RuntimeError(
                f"offline regen requires _sheets/{sprite_name}.png to "
                "be committed; run `make sprites` with OPENAI_API_KEY set"
            )
        return sheet

    key = cache_key(
        world_md, entry_md, _LEGACY_FIXED_INSTRUCTIONS, model_id,
        sprite_name=sprite_name,
    )
    cached = read_cache(key)
    if cached is not None:
        if on_cache_hit is not None:
            on_cache_hit(sprite_name)
        if read_sheet(sprite_name) is None:
            write_sheet(sprite_name, cached)
        return cached

    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        raise RuntimeError(
            "OPENAI_API_KEY is not set in the environment — required "
            "for online sprite generation. Use `--offline` to skip."
        )
    fresh = _generate_single_sprite(
        sprite_name=sprite_name,
        role=role,
        entry=entry,
        entry_md=entry_md,
        world_md=world_md,
        api_key=api_key,
        model_id=model_id,
    )
    write_cache(key, fresh, api_response_json=None)
    write_sheet(sprite_name, fresh)
    return _read_back(sprite_name)


def _read_back(sprite_name: str) -> Image.Image:
    sheet = read_sheet(sprite_name)
    if sheet is None:
        raise RuntimeError(
            f"failed to read back just-written sheet for {sprite_name}"
        )
    return sheet


def _is_procedural(entry: CatalogEntry) -> bool:
    """`source = "procedural"` entries are drawn locally by
    `procedural.render_sheet` instead of the image API."""
    return entry.front_matter.get("source", "").strip().lower() == "procedural"


def _is_derived_operational(entry: CatalogEntry, sprite_name: str) -> bool:
    """`operational = "derived"` entries build their operational
    frames from the base sprite instead of drawing each one separately,
    so the animation never swaps one building for a different one."""
    derived = entry.front_matter.get("operational", "").strip().lower() == "derived"
    return derived and _is_operational_frame(sprite_name)


def _derived_sheet(entry: CatalogEntry, sprite_name: str) -> Image.Image:
    base_name = _base_name_for_kind(sprite_name)
    base_sheet = read_sheet(base_name)
    if base_sheet is None:
        raise RuntimeError(f"derived frame {sprite_name} needs _sheets/{base_name}.png")
    target = _target_size(base_name)
    base = quantize(downsample(threshold_alpha(base_sheet, threshold=128), target, mode="nearest"), PALETTE)
    frames = sorted(name for _, name in slice_plan(entry) if _is_operational_frame(name))
    index = int(sprite_name.rsplit("-", 1)[1])
    derived = procedural.derive_operational(base, index, len(frames))
    return derived.resize((procedural.SHEET_SIZE, procedural.SHEET_SIZE), resample=Image.Resampling.NEAREST)


def write_procedural_sheets() -> list[str]:
    """Write `_sheets/<sprite>.png` for every sprite that is drawn
    locally: all sprites of procedural catalog entries, plus the
    operational frames of `operational = "derived"` entries. Returns
    the sprite names written. Needs no API key; follow with an offline
    run to refresh the atlases."""
    written: list[str] = []
    for md in sorted(paths.CATALOG_DIR.glob("*.md")):
        entry = parse_catalog_entry(md.stem, md.read_text(encoding="utf-8"))
        for _, sprite_name in slice_plan(entry):
            if _is_procedural(entry):
                write_sheet(sprite_name, procedural.render_sheet(sprite_name))
            elif _is_derived_operational(entry, sprite_name):
                write_sheet(sprite_name, _derived_sheet(entry, sprite_name))
            else:
                continue
            written.append(sprite_name)
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
    """Walk the catalog and regenerate every atlas PNG, one API call
    per sprite (post-rewrite — pre-rewrite this was one call per kind
    + slicing; see this module's docstring).

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

    # Build the work list: one (entry, sprite-name, role) tuple per
    # atlas PNG the catalog declares. Sort within-entry first
    # (base/construction before operational) so two-pass mode's
    # operational anchor (the just-written base sheet) is available
    # when its operational frames run.
    work_items: list[tuple[CatalogEntry, str, str, str]] = []
    for md in sorted(paths.CATALOG_DIR.glob("*.md")):
        text = md.read_text(encoding="utf-8")
        entry = parse_catalog_entry(md.stem, text)
        role_map = build_role_map(text)
        plan = slice_plan(entry)
        # Stable in-entry ordering: non-operational sprites first.
        plan = sorted(plan, key=lambda kv: (_is_operational_frame(kv[1]), kv[0]))
        for _, sprite_name in plan:
            role = role_for(sprite_name, role_map)
            work_items.append((entry, text, sprite_name, role))

    if not work_items:
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

    def work(item: tuple[CatalogEntry, str, str, str]) -> Path:
        entry, entry_md, sprite_name, role = item
        raw = _sprite_for_atlas_name(
            sprite_name, role, entry, entry_md, world_md, model_id,
            effective_offline,
            on_cache_hit=lambda n: print(f"[cache hit] {n}", flush=True),
        )
        return _process_and_write_cell(sprite_name, raw, output_resolver)

    try:
        written: list[Path] = []
        if effective_offline:
            # Offline path is deterministic and CPU-bound; run
            # sequentially so the ordered log output stays stable.
            for item in work_items:
                written.append(work(item))
        else:
            # Two-pass operational frames depend on their kind's base
            # sprite being on disk before they run. Split the work
            # into a base-and-construction phase (everything that
            # isn't an operational frame for a two-pass entry) and an
            # operational phase, and run them sequentially.
            base_phase: list[tuple[CatalogEntry, str, str, str]] = []
            op_phase: list[tuple[CatalogEntry, str, str, str]] = []
            for item in work_items:
                entry, _, sprite_name, _ = item
                if _is_two_pass(entry) and _is_operational_frame(sprite_name):
                    op_phase.append(item)
                else:
                    base_phase.append(item)
            for phase in (base_phase, op_phase):
                if not phase:
                    continue
                with concurrent.futures.ThreadPoolExecutor(max_workers=max_inflight) as ex:
                    futures = {ex.submit(work, it): it[2] for it in phase}
                    for fut in concurrent.futures.as_completed(futures):
                        name = futures[fut]
                        try:
                            written.append(fut.result())
                            print(f"[done] {name}", flush=True)
                        except Exception as exc:
                            print(f"[fail] {name}: {exc}", flush=True)
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
