"""Pure-function tests for `generate_sprites_ai.slicer`.

`slice_plan(entry) -> [((row, col), atlas_filename)]` is the contract
between a catalog entry's `Sheet` section and the output PNG filenames.
The function MUST be deterministic and MUST produce filenames that
conform to the `sprite-asset-pipeline` naming grammar.

`slice_sheet(image, plan) -> [(filename, image)]` cuts a generated
sheet into per-cell images.
"""

from __future__ import annotations

import re
from pathlib import Path

from PIL import Image

from generate_sprites_ai.slicer import (
    parse_catalog_entry,
    slice_plan,
    slice_sheet,
)


REPO_ROOT = Path(__file__).resolve().parent.parent.parent
CATALOG_DIR = REPO_ROOT / "Resources" / "Sprites.style" / "catalog"


# Sprite-asset-pipeline naming grammar (capability `sprite-asset-pipeline`,
# Requirement: Sprite naming grammar). All atlas filenames produced by
# slice_plan MUST match one of these patterns.
NAME_PATTERNS = [
    # Terrain: terrain-<kind>[-v<n>][-<season>][-<frame>]
    re.compile(r"^terrain-[a-z]+(?:-v\d+)?(?:-(?:autumn|winter))?(?:-\d+)?$"),
    # Land building: building-<kind>[-v<n>][-(constructing|operational)-<n>]
    re.compile(
        r"^building-(?!port|shipyard)[a-z0-9-]+?(?:-v\d+)?"
        r"(?:-(?:constructing|operational)-\d+)?$"
    ),
    # Shore building: building-(port|shipyard)-(n|s|e|w)[-(constructing|operational)-<n>]
    re.compile(
        r"^building-(?:port|shipyard)-[nsew]"
        r"(?:-(?:constructing|operational)-\d+)?$"
    ),
    # Walker
    re.compile(r"^walker-(?:ne|nw|se|sw)-\d+$"),
    # Ship
    re.compile(r"^ship-(?:n|ne|e|se|s|sw|w|nw)-\d+$"),
    # Goods icon
    re.compile(r"^good-[a-z]+(?:-[a-z]+)*$"),
]


def _conforms_to_grammar(name: str) -> bool:
    return any(p.match(name) for p in NAME_PATTERNS)


def test_parse_catalog_entry_basic() -> None:
    text = """\
## Function
Test.

## Visual identity
Test visual.

## Sheet
Grid: 2 cols × 1 rows.

- (0, 0): `building-house`
- (0, 1): `building-house-constructing-0`

## Animation
- Construction: `(0, 0)` → `(0, 1)`.
"""
    entry = parse_catalog_entry("building-house", text)
    assert entry.id == "building-house"
    assert entry.grid == (2, 1)
    assert entry.cells == {(0, 0): "building-house", (0, 1): "building-house-constructing-0"}


def test_slice_plan_skips_spare_cells() -> None:
    text = """\
## Function
Test.

## Visual identity
Test.

## Sheet
Grid: 2 cols × 1 rows.

- (0, 0): `building-house`
- (0, 1): spare

## Animation
Static.
"""
    entry = parse_catalog_entry("building-house", text)
    plan = slice_plan(entry)
    assert plan == [((0, 0), "building-house")]


def test_slice_plan_is_deterministic() -> None:
    text = """\
## Function
T

## Visual identity
T

## Sheet
Grid: 3 cols × 1 rows.

- (0, 0): `terrain-grass`
- (0, 1): `terrain-grass-0`
- (0, 2): `terrain-grass-1`

## Animation
- Wind: `(0, 1)` → `(0, 2)`.
"""
    entry = parse_catalog_entry("terrain-grass", text)
    a = slice_plan(entry)
    b = slice_plan(entry)
    assert a == b
    assert a == [
        ((0, 0), "terrain-grass"),
        ((0, 1), "terrain-grass-0"),
        ((0, 2), "terrain-grass-1"),
    ]


def test_slice_plan_covers_every_non_spare_cell() -> None:
    """Walk every catalog entry on disk and verify slice_plan returns
    one tuple per non-spare cell, with no duplicates."""
    for md in sorted(CATALOG_DIR.glob("*.md")):
        text = md.read_text(encoding="utf-8")
        entry = parse_catalog_entry(md.stem, text)
        plan = slice_plan(entry)
        coords = [c for c, _ in plan]
        assert len(coords) == len(set(coords)), f"{md.name}: duplicate coords"
        # Cross-check: every non-spare cell in entry.cells is in plan.
        non_spare = {c for c, v in entry.cells.items() if v != "spare"}
        assert set(coords) == non_spare, f"{md.name}: plan / cells mismatch"


def test_slice_plan_output_filenames_conform_to_naming_grammar() -> None:
    for md in sorted(CATALOG_DIR.glob("*.md")):
        text = md.read_text(encoding="utf-8")
        entry = parse_catalog_entry(md.stem, text)
        for (_, fname) in slice_plan(entry):
            assert _conforms_to_grammar(fname), \
                f"{md.name}: filename `{fname}` violates naming grammar"


def test_slice_sheet_cuts_each_cell() -> None:
    text = """\
## Function
T

## Visual identity
T

## Sheet
Grid: 2 cols × 1 rows.

- (0, 0): `building-house`
- (0, 1): `building-house-constructing-0`

## Animation
- Construction: `(0, 0)` → `(0, 1)`.
"""
    entry = parse_catalog_entry("building-house", text)
    sheet = Image.new("RGB", (1536, 1024), (255, 0, 255))
    plan = slice_plan(entry)
    results = slice_sheet(sheet, plan, grid=entry.grid, sheet_size=(1536, 1024))
    assert len(results) == 2
    names = [name for name, _ in results]
    assert names == ["building-house", "building-house-constructing-0"]
    for _, img in results:
        assert img.size == (768, 1024)
