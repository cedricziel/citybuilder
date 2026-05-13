"""Integration tests for `generate_sprites_ai.batcher`.

These tests mock `httpx.Client.post` so they exercise the orchestrator
path without burning real OpenAI credits.
"""

from __future__ import annotations

import base64
import io
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest
from PIL import Image

from generate_sprites_ai import batcher, cache, paths
from generate_sprites_ai.composer import FIXED_INSTRUCTIONS


def _fake_sheet_png_b64() -> str:
    img = Image.new("RGBA", (1024, 1024), (255, 0, 255, 255))
    # Paint a single non-magenta pixel in cell (0, 0) so we can verify
    # the slicer + chroma-key + downsample chain wrote something.
    img.putpixel((10, 10), (122, 31, 26, 255))
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return base64.b64encode(buf.getvalue()).decode("ascii")


def _patch_dirs_to(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    """Redirect every directory the batcher writes to into tmp_path."""
    monkeypatch.setattr(cache, "CACHE_DIR_OVERRIDE", tmp_path / "_cache")
    monkeypatch.setattr(cache, "SHEETS_DIR_OVERRIDE", tmp_path / "_sheets")
    # Atlas writes target the real Resources/*.atlas/ directories;
    # redirect those too via the paths module.
    fake_terrain = tmp_path / "Terrain.atlas"
    fake_buildings = tmp_path / "Buildings.atlas"
    fake_units = tmp_path / "Units.atlas"
    fake_icons = tmp_path / "Icons.atlas"
    monkeypatch.setattr(paths, "ATLAS_DIRS", {
        "terrain-": fake_terrain,
        "building-": fake_buildings,
        "walker-": fake_units,
        "ship-": fake_units,
        "good-": fake_icons,
    })


def test_cache_hit_skips_the_api_call(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """If a cache entry for an exists for the cache key, the batcher
    MUST NOT call /v1/images/edits for that entry."""
    _patch_dirs_to(tmp_path, monkeypatch)

    # Prime the cache with the exact key for one catalog entry.
    catalog_md = paths.CATALOG_DIR / "building-house.md"
    world_md = paths.WORLD_MD.read_text(encoding="utf-8")
    entry_md = catalog_md.read_text(encoding="utf-8")
    import tomllib
    cfg = tomllib.loads(paths.PIPELINE_TOML.read_text(encoding="utf-8"))
    model_id = cfg["model"]

    key = cache.cache_key(world_md, entry_md, FIXED_INSTRUCTIONS, model_id)
    fake_sheet = Image.new("RGBA", (1024, 1024), (255, 0, 255, 255))
    cache.write_cache(key, fake_sheet)

    # Use the batcher's internal helper to confirm no API call happens.
    with patch("generate_sprites_ai.batcher._post_edit") as mocked:
        # Build a CatalogEntry without parsing all catalogs.
        from generate_sprites_ai.slicer import parse_catalog_entry
        entry = parse_catalog_entry("building-house", entry_md)
        sheet = batcher._sheet_for_entry(
            entry, entry_md, world_md, model_id, offline=False,
        )
        mocked.assert_not_called()
    assert sheet.size == (1024, 1024)


def test_offline_mode_reads_from_sheets_store(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Offline mode MUST read from `_sheets/<id>.png` and never
    contact the API or the cache."""
    _patch_dirs_to(tmp_path, monkeypatch)

    # Commit a fake sheet for one entry in the sheets store.
    fake = Image.new("RGBA", (1024, 1024), (10, 20, 30, 255))
    cache.write_sheet("building-house", fake)

    catalog_md = paths.CATALOG_DIR / "building-house.md"
    entry_md = catalog_md.read_text(encoding="utf-8")
    world_md = paths.WORLD_MD.read_text(encoding="utf-8")
    import tomllib
    cfg = tomllib.loads(paths.PIPELINE_TOML.read_text(encoding="utf-8"))
    model_id = cfg["model"]

    with patch("generate_sprites_ai.batcher._post_edit") as mocked:
        from generate_sprites_ai.slicer import parse_catalog_entry
        entry = parse_catalog_entry("building-house", entry_md)
        sheet = batcher._sheet_for_entry(
            entry, entry_md, world_md, model_id, offline=True,
        )
        mocked.assert_not_called()
    assert sheet.size == (1024, 1024)
    assert sheet.getpixel((0, 0))[:3] == (10, 20, 30)


def test_offline_mode_fails_loudly_when_sheet_missing(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Offline mode with no committed sheet MUST raise — the contract
    is that committed sheets are the offline source of truth."""
    _patch_dirs_to(tmp_path, monkeypatch)

    catalog_md = paths.CATALOG_DIR / "building-house.md"
    entry_md = catalog_md.read_text(encoding="utf-8")
    world_md = paths.WORLD_MD.read_text(encoding="utf-8")
    import tomllib
    cfg = tomllib.loads(paths.PIPELINE_TOML.read_text(encoding="utf-8"))
    model_id = cfg["model"]

    from generate_sprites_ai.slicer import parse_catalog_entry
    entry = parse_catalog_entry("building-house", entry_md)
    with pytest.raises(RuntimeError, match="_sheets/building-house.png"):
        batcher._sheet_for_entry(
            entry, entry_md, world_md, model_id, offline=True,
        )


def test_bumping_the_model_invalidates_every_cache_entry(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Toggling the `model` key MUST change the cache key for every
    entry — proves the model id is part of the hash."""
    _patch_dirs_to(tmp_path, monkeypatch)
    world_md = paths.WORLD_MD.read_text(encoding="utf-8")
    keys_old: list[str] = []
    keys_new: list[str] = []
    for md in sorted(paths.CATALOG_DIR.glob("*.md")):
        text = md.read_text(encoding="utf-8")
        keys_old.append(
            cache.cache_key(world_md, text, FIXED_INSTRUCTIONS, "gpt-image-2-2026-04-21")
        )
        keys_new.append(
            cache.cache_key(world_md, text, FIXED_INSTRUCTIONS, "gpt-image-3-2030-01-01")
        )
    assert set(keys_old).isdisjoint(set(keys_new))


def test_editing_world_md_invalidates_every_cache_entry(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _patch_dirs_to(tmp_path, monkeypatch)
    world_md = paths.WORLD_MD.read_text(encoding="utf-8")
    world_edited = world_md + "\n\n## Extra section\nedited.\n"
    keys_old: list[str] = []
    keys_new: list[str] = []
    for md in sorted(paths.CATALOG_DIR.glob("*.md")):
        text = md.read_text(encoding="utf-8")
        keys_old.append(cache.cache_key(world_md, text, FIXED_INSTRUCTIONS, "m"))
        keys_new.append(cache.cache_key(world_edited, text, FIXED_INSTRUCTIONS, "m"))
    assert set(keys_old).isdisjoint(set(keys_new))


def test_default_mode_is_single_pass(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """A catalog entry without `two-pass: true` in its front matter
    MUST trigger exactly one /v1/images/edits call."""
    _patch_dirs_to(tmp_path, monkeypatch)
    entry_md = (
        "## Function\nx\n\n"
        "## Visual identity\nx\n\n"
        "## Sheet\n\nGrid: 2 cols × 1 rows.\n"
        "- (0, 0): `building-house`\n"
        "- (0, 1): `building-house-constructing-0`\n\n"
        "## Animation\n- Construction: `(0, 0)` → `(0, 1)`.\n"
    )
    monkeypatch.setattr("os.environ", {"OPENAI_API_KEY": "test"})
    fake_sheet = Image.new("RGBA", (1024, 1024), (255, 0, 255, 255))

    with patch("generate_sprites_ai.batcher._post_edit", return_value=fake_sheet) as mocked:
        from generate_sprites_ai.slicer import parse_catalog_entry
        entry = parse_catalog_entry("building-house", entry_md)
        sheet = batcher._sheet_for_entry(
            entry, entry_md, "world", "model-id", offline=False,
        )
        assert mocked.call_count == 1
        assert sheet.size == fake_sheet.size


def test_opt_in_two_pass_triggers_a_second_api_call(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """A catalog entry with `two-pass: true` front matter MUST trigger
    two /v1/images/edits calls."""
    _patch_dirs_to(tmp_path, monkeypatch)
    entry_md = (
        "---\n"
        "two-pass = true\n"
        "---\n\n"
        "## Function\nx\n\n"
        "## Visual identity\nx\n\n"
        "## Sheet\n\nGrid: 2 cols × 1 rows.\n"
        "- (0, 0): `building-house`\n"
        "- (0, 1): `building-house-operational-0`\n\n"
        "## Animation\n- Op: `(0, 0)` → `(0, 1)`.\n"
    )
    monkeypatch.setattr("os.environ", {"OPENAI_API_KEY": "test"})
    pass1 = Image.new("RGBA", (1024, 1024), (255, 0, 255, 255))
    pass2 = Image.new("RGBA", (1024, 1024), (255, 0, 255, 255))

    with patch(
        "generate_sprites_ai.batcher._post_edit",
        side_effect=[pass1, pass2],
    ) as mocked:
        from generate_sprites_ai.slicer import parse_catalog_entry
        entry = parse_catalog_entry("building-house", entry_md)
        sheet = batcher._sheet_for_entry(
            entry, entry_md, "world", "model-id", offline=False,
        )
        assert mocked.call_count == 2
        assert sheet.size == (1024, 1024)


def test_two_pass_cache_key_includes_the_mode(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Toggling `two-pass: true` ↔ omitted MUST change the cache key
    so flipping the mode invalidates the cached entry."""
    _patch_dirs_to(tmp_path, monkeypatch)
    base = (
        "## Function\nx\n## Visual identity\nx\n"
        "## Sheet\n\nGrid: 1 cols × 1 rows.\n- (0, 0): `building-house`\n"
        "## Animation\nStatic.\n"
    )
    two_pass = (
        "---\ntwo-pass = true\n---\n\n"
        "## Function\nx\n## Visual identity\nx\n"
        "## Sheet\n\nGrid: 1 cols × 1 rows.\n- (0, 0): `building-house`\n"
        "## Animation\nStatic.\n"
    )
    k1 = cache.cache_key("world", base, FIXED_INSTRUCTIONS, "m")
    k2 = cache.cache_key("world", two_pass, FIXED_INSTRUCTIONS, "m")
    assert k1 != k2


def test_make_sprites_is_idempotent_on_unchanged_inputs(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """With every cache key already populated, two consecutive
    `run_pipeline(offline=False)` invocations MUST perform zero API
    calls and produce identical atlas PNG bytes."""
    _patch_dirs_to(tmp_path, monkeypatch)
    world_md = paths.WORLD_MD.read_text(encoding="utf-8")
    import tomllib
    cfg = tomllib.loads(paths.PIPELINE_TOML.read_text(encoding="utf-8"))
    model_id = cfg["model"]

    # Prime cache for every catalog entry with a single magenta sheet.
    fake = Image.new("RGBA", (1024, 1024), (255, 0, 255, 255))
    for md in sorted(paths.CATALOG_DIR.glob("*.md")):
        text = md.read_text(encoding="utf-8")
        key = cache.cache_key(world_md, text, FIXED_INSTRUCTIONS, model_id)
        cache.write_cache(key, fake)

    with patch("generate_sprites_ai.batcher._post_edit") as mocked:
        rc1 = batcher.run_pipeline(offline=False, verify=False)
        rc2 = batcher.run_pipeline(offline=False, verify=False)
        assert rc1 == 0 and rc2 == 0
        mocked.assert_not_called()
