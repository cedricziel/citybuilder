"""Integration tests for `generate_sprites_ai.batcher`.

These tests mock `_post_edit` (the per-sprite API call) so they
exercise the orchestrator path without burning real OpenAI credits.
"""

from __future__ import annotations

import tomllib
from pathlib import Path
from unittest.mock import patch

import pytest
from PIL import Image

from generate_sprites_ai import batcher, cache, paths
from generate_sprites_ai.slicer import parse_catalog_entry


def _patch_dirs_to(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    """Redirect every directory the batcher writes to into tmp_path."""
    monkeypatch.setattr(cache, "CACHE_DIR_OVERRIDE", tmp_path / "_cache")
    monkeypatch.setattr(cache, "SHEETS_DIR_OVERRIDE", tmp_path / "_sheets")
    monkeypatch.setattr(paths, "ATLAS_DIRS", {
        "terrain-": tmp_path / "Terrain.atlas",
        "building-": tmp_path / "Buildings.atlas",
        "walker-": tmp_path / "Units.atlas",
        "ship-": tmp_path / "Units.atlas",
        "good-": tmp_path / "Icons.atlas",
    })


def _read_pipeline_model() -> str:
    return tomllib.loads(paths.PIPELINE_TOML.read_text(encoding="utf-8"))["model"]


def test_cache_hit_skips_the_api_call(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """If a cache entry exists for the sprite-name's key, the batcher
    MUST NOT call `_post_edit` for that sprite."""
    _patch_dirs_to(tmp_path, monkeypatch)
    catalog_md = paths.CATALOG_DIR / "building-house.md"
    world_md = paths.WORLD_MD.read_text(encoding="utf-8")
    entry_md = catalog_md.read_text(encoding="utf-8")
    model_id = _read_pipeline_model()

    sprite_name = "building-house"
    key = cache.cache_key(
        world_md, entry_md, batcher._LEGACY_FIXED_INSTRUCTIONS, model_id,
        sprite_name=sprite_name,
    )
    fake = Image.new("RGBA", (1024, 1024), (255, 0, 255, 255))
    cache.write_cache(key, fake)

    with patch("generate_sprites_ai.batcher._post_edit") as mocked:
        entry = parse_catalog_entry("building-house", entry_md)
        out = batcher._sprite_for_atlas_name(
            sprite_name, "test role", entry, entry_md, world_md, model_id,
            offline=False,
        )
        mocked.assert_not_called()
    assert out.size == (1024, 1024)


def test_offline_mode_reads_from_sheets_store(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Offline mode MUST read from `_sheets/<sprite-name>.png` and
    never contact the API or the cache."""
    _patch_dirs_to(tmp_path, monkeypatch)
    sprite_name = "building-house"
    fake = Image.new("RGBA", (1024, 1024), (10, 20, 30, 255))
    cache.write_sheet(sprite_name, fake)

    catalog_md = paths.CATALOG_DIR / "building-house.md"
    entry_md = catalog_md.read_text(encoding="utf-8")
    world_md = paths.WORLD_MD.read_text(encoding="utf-8")
    model_id = _read_pipeline_model()

    with patch("generate_sprites_ai.batcher._post_edit") as mocked:
        entry = parse_catalog_entry("building-house", entry_md)
        out = batcher._sprite_for_atlas_name(
            sprite_name, "test role", entry, entry_md, world_md, model_id,
            offline=True,
        )
        mocked.assert_not_called()
    assert out.size == (1024, 1024)
    assert out.getpixel((0, 0))[:3] == (10, 20, 30)


def test_offline_mode_fails_loudly_when_sheet_missing(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Offline mode with no committed sheet for the requested sprite
    MUST raise — committed sheets are the offline source of truth."""
    _patch_dirs_to(tmp_path, monkeypatch)
    catalog_md = paths.CATALOG_DIR / "building-house.md"
    entry_md = catalog_md.read_text(encoding="utf-8")
    world_md = paths.WORLD_MD.read_text(encoding="utf-8")
    model_id = _read_pipeline_model()

    entry = parse_catalog_entry("building-house", entry_md)
    with pytest.raises(RuntimeError, match="_sheets/building-house.png"):
        batcher._sprite_for_atlas_name(
            "building-house", "test role", entry, entry_md, world_md,
            model_id, offline=True,
        )


def test_bumping_the_model_invalidates_every_cache_entry(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Toggling the `model` key MUST change the cache key for every
    sprite — proves the model id is part of the hash."""
    _patch_dirs_to(tmp_path, monkeypatch)
    world_md = paths.WORLD_MD.read_text(encoding="utf-8")
    keys_old: list[str] = []
    keys_new: list[str] = []
    for md in sorted(paths.CATALOG_DIR.glob("*.md")):
        text = md.read_text(encoding="utf-8")
        keys_old.append(cache.cache_key(world_md, text, "", "gpt-image-1", sprite_name=md.stem))
        keys_new.append(cache.cache_key(world_md, text, "", "gpt-image-9", sprite_name=md.stem))
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
        keys_old.append(cache.cache_key(world_md, text, "", "m", sprite_name=md.stem))
        keys_new.append(cache.cache_key(world_edited, text, "", "m", sprite_name=md.stem))
    assert set(keys_old).isdisjoint(set(keys_new))


def test_cache_key_is_per_sprite_name_within_a_kind(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Each sprite-name within a multi-cell catalog kind MUST get its
    own cache slot. Editing one sprite's role-driven prompt would
    otherwise invalidate every other sprite of the kind too."""
    keys = {
        name: cache.cache_key("world", "entry", "", "m", sprite_name=name)
        for name in (
            "building-house",
            "building-house-constructing-0",
            "building-house-constructing-1",
        )
    }
    assert len(set(keys.values())) == 3


def test_default_mode_is_single_pass(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """A catalog entry without `two-pass: true` in its front matter
    MUST trigger exactly one API call per atlas sprite."""
    _patch_dirs_to(tmp_path, monkeypatch)
    entry_md = (
        "## Function\nx\n\n"
        "## Visual identity\nx\n\n"
        "## Sheet\n\nGrid: 1 cols × 1 rows.\n"
        "- (0, 0): `building-house`\n\n"
        "## Animation\nStatic.\n"
    )
    monkeypatch.setattr("os.environ", {"OPENAI_API_KEY": "test"})
    fake = Image.new("RGBA", (1024, 1024), (10, 20, 30, 255))

    with patch("generate_sprites_ai.batcher._post_edit", return_value=fake) as mocked:
        entry = parse_catalog_entry("building-house", entry_md)
        batcher._sprite_for_atlas_name(
            "building-house", "test role", entry, entry_md, "world", "m",
            offline=False,
        )
        assert mocked.call_count == 1


def test_two_pass_operational_anchors_on_base_sprite(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """In two-pass mode, an operational-frame sprite call MUST pass
    `_sheets/<base>.png` as the anchor image, not the global
    master-reference. Confirms operational frames inherit pixel
    coherence from the just-generated base sprite."""
    _patch_dirs_to(tmp_path, monkeypatch)
    entry_md = (
        "---\ntwo-pass = true\n---\n"
        "## Function\nx\n## Visual identity\nx\n"
        "## Sheet\n\nGrid: 1 cols × 1 rows.\n"
        "- (0, 0): `building-house-operational-0`\n"
        "## Animation\nStatic.\n"
    )
    monkeypatch.setattr("os.environ", {"OPENAI_API_KEY": "test"})
    fake_base = Image.new("RGBA", (1024, 1024), (50, 60, 70, 255))
    cache.write_sheet("building-house", fake_base)

    fake_op = Image.new("RGBA", (1024, 1024), (10, 20, 30, 255))
    seen_anchor: dict[str, Path] = {}

    def fake_post_edit(*, master_reference_path: Path, **_kw: object) -> Image.Image:
        seen_anchor["path"] = master_reference_path
        return fake_op

    with patch("generate_sprites_ai.batcher._post_edit", side_effect=fake_post_edit):
        entry = parse_catalog_entry("building-house", entry_md)
        batcher._sprite_for_atlas_name(
            "building-house-operational-0", "op frame 0", entry, entry_md,
            "world", "m", offline=False,
        )

    assert seen_anchor["path"].name == "building-house.png"
    assert seen_anchor["path"].parent == tmp_path / "_sheets"


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
    k1 = cache.cache_key("world", base, "", "m", sprite_name="building-house")
    k2 = cache.cache_key("world", two_pass, "", "m", sprite_name="building-house")
    assert k1 != k2


def test_make_sprites_is_idempotent_on_unchanged_inputs(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """With every per-sprite cache key already populated, two
    consecutive `run_pipeline(offline=False)` invocations MUST perform
    zero API calls."""
    _patch_dirs_to(tmp_path, monkeypatch)
    world_md = paths.WORLD_MD.read_text(encoding="utf-8")
    model_id = _read_pipeline_model()

    # Prime per-sprite cache for every sprite the catalog declares.
    fake = Image.new("RGBA", (1024, 1024), (255, 0, 255, 255))
    from generate_sprites_ai.slicer import slice_plan
    for md in sorted(paths.CATALOG_DIR.glob("*.md")):
        text = md.read_text(encoding="utf-8")
        entry = parse_catalog_entry(md.stem, text)
        for _, sprite_name in slice_plan(entry):
            key = cache.cache_key(
                world_md, text, batcher._LEGACY_FIXED_INSTRUCTIONS, model_id,
                sprite_name=sprite_name,
            )
            cache.write_cache(key, fake)

    with patch("generate_sprites_ai.batcher._post_edit") as mocked:
        rc1 = batcher.run_pipeline(offline=False, verify=False)
        rc2 = batcher.run_pipeline(offline=False, verify=False)
        assert rc1 == 0 and rc2 == 0
        mocked.assert_not_called()


def test_build_role_map_extracts_per_sprite_descriptions() -> None:
    """The role-map parser pulls trailing role text from cell lines
    like `- (0, 1): \`building-house-constructing-0\` — foundation stage`."""
    text = (
        "## Sheet\n\n"
        "Grid: 2 cols × 1 rows.\n\n"
        "- (0, 0): `building-house` — canonical operational base\n"
        "- (0, 1): `building-house-constructing-0` — foundation stage\n"
        "- (1, 0): spare\n"
    )
    role_map = batcher.build_role_map(text)
    assert role_map["building-house"] == "canonical operational base"
    assert role_map["building-house-constructing-0"] == "foundation stage"
    assert "spare" not in role_map


def test_role_for_falls_back_for_walker_and_ship() -> None:
    """Walker / ship sprites with no explicit cell-line description
    fall back to a derived role from their filename."""
    assert "facing ne" in batcher.role_for("walker-ne-0", {})
    assert "facing sw" in batcher.role_for("walker-sw-1", {})
    assert "facing nw" in batcher.role_for("ship-nw-1", {})
    assert "goods icon" in batcher.role_for("good-wood", {})


# ---------------- procedural source ----------------

_PROCEDURAL_ENTRY = """---
source = "procedural"
---
## Function

Water.

## Sheet

Grid: 2 cols × 1 rows.

- (0, 0): `terrain-water` — base
- (0, 1): `terrain-water-0` — frame
"""


def test_procedural_entry_never_calls_the_api(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """A `source = "procedural"` entry is drawn locally: no API key,
    no `_post_edit`, and the sheet lands in `_sheets/` for offline
    regen."""
    _patch_dirs_to(tmp_path, monkeypatch)
    monkeypatch.delenv("OPENAI_API_KEY", raising=False)
    entry = parse_catalog_entry("terrain-water", _PROCEDURAL_ENTRY)

    with patch("generate_sprites_ai.batcher._post_edit") as mocked:
        out = batcher._sprite_for_atlas_name(
            "terrain-water", "base", entry, _PROCEDURAL_ENTRY,
            paths.WORLD_MD.read_text(encoding="utf-8"), _read_pipeline_model(),
            offline=False,
        )
        mocked.assert_not_called()

    assert out.size == (1024, 1024)
    assert cache.read_sheet("terrain-water") is not None


def test_procedural_regen_writes_sheets_only_for_procedural_entries(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _patch_dirs_to(tmp_path, monkeypatch)
    catalog = tmp_path / "catalog"
    catalog.mkdir()
    (catalog / "terrain-water.md").write_text(_PROCEDURAL_ENTRY, encoding="utf-8")
    (catalog / "building-house.md").write_text(
        (paths.CATALOG_DIR / "building-house.md").read_text(encoding="utf-8"),
        encoding="utf-8",
    )
    monkeypatch.setattr(paths, "CATALOG_DIR", catalog)

    written = batcher.write_procedural_sheets()

    assert sorted(written) == ["terrain-water", "terrain-water-0"]
    assert cache.read_sheet("building-house") is None


def test_terrain_cells_are_diamond_fitted(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """A terrain sprite whose opaque blob fills only the tile centre
    comes out covering the full diamond."""
    _patch_dirs_to(tmp_path, monkeypatch)
    sheet = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    for y in range(384, 640):
        for x in range(384, 640):
            sheet.putpixel((x, y), (0x5C, 0x80, 0x38, 255))

    out = batcher._process_and_write_cell("terrain-grass", sheet)

    img = Image.open(out).convert("RGBA")
    from generate_sprites_ai.postprocess import in_diamond
    inside = [img.getpixel((x, y))[3] for y in range(32) for x in range(64) if in_diamond(x, y, 64, 32)]
    assert sum(1 for a in inside if a) / len(inside) >= 0.9


_DERIVED_ENTRY = """---
operational = "derived"
---
## Function

Mill.

## Sheet

Grid: 3 cols × 1 rows.

- (0, 0): `building-sawmill` — base
- (0, 1): `building-sawmill-operational-0` — frame
- (0, 2): `building-sawmill-operational-1` — frame
"""


def test_derived_operational_frames_reuse_the_base_building(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """With `operational = "derived"`, operational sheets are built
    from the processed base sprite, so the building's lower part is
    pixel-identical across base and frames."""
    _patch_dirs_to(tmp_path, monkeypatch)
    catalog = tmp_path / "catalog"
    catalog.mkdir()
    (catalog / "building-sawmill.md").write_text(_DERIVED_ENTRY, encoding="utf-8")
    monkeypatch.setattr(paths, "CATALOG_DIR", catalog)
    base_sheet = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    for y in range(300, 1000):
        for x in range(200, 800):
            base_sheet.putpixel((x, y), (0x6E, 0x4A, 0x2A, 255))
    cache.write_sheet("building-sawmill", base_sheet)

    written = batcher.write_procedural_sheets()

    assert sorted(written) == ["building-sawmill-operational-0", "building-sawmill-operational-1"]
    base = Image.open(batcher._process_and_write_cell("building-sawmill", cache.read_sheet("building-sawmill")))
    frame = Image.open(batcher._process_and_write_cell(
        "building-sawmill-operational-0", cache.read_sheet("building-sawmill-operational-0")
    ))
    w, h = base.size
    lower = (0, h // 2, w, h)
    assert base.convert("RGBA").crop(lower).tobytes() == frame.convert("RGBA").crop(lower).tobytes()
