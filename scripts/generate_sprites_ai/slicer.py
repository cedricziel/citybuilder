"""Pure catalog-parsing and sheet-slicing module.

`parse_catalog_entry(id, markdown_text) -> CatalogEntry` walks the
Markdown headings and parses the `## Sheet` and `## Animation`
sections.

`slice_plan(entry) -> [((row, col), atlas_filename)]` is the contract
between the catalog entry's `Sheet` section and the output PNG
filenames. Spare cells produce no output (they are skipped, not
written).

`slice_sheet(image, plan, grid, sheet_size) -> [(filename, image)]`
cuts a generated sheet image into per-cell tiles.

Pure functions; Pillow only. No I/O outside what the caller hands in.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Iterable

from PIL import Image


# YAML front matter is optional and lives at the very top of a file.
_FRONT_MATTER_RE = re.compile(r"\A---\n(.*?)\n---\n", re.DOTALL)
# `## Foo` level-2 ATX heading.
_HEADING_RE = re.compile(r"^##\s+(.+?)\s*$", re.MULTILINE)
# `(row, col)` coordinate pair.
_COORD_RE = re.compile(r"\((\d+)\s*,\s*(\d+)\)")
# `Grid: N cols × M rows` (or just `Grid: N×M`).
_GRID_RE = re.compile(
    r"Grid:\s*(\d+)\s*(?:cols?\s*[x×*]\s*|[x×*])\s*(\d+)",
    re.IGNORECASE,
)
# Match an assignment line like:
#   - (0, 0): `building-sawmill`
#   - (1, 1): spare
_CELL_ASSIGNMENT_RE = re.compile(
    r"\(\s*(\d+)\s*,\s*(\d+)\s*\)\s*:\s*"
    r"(?:`([^`]+)`|([A-Za-z][\w-]*))"
)


@dataclass
class CatalogEntry:
    """Parsed representation of a `Resources/Sprites.style/catalog/<id>.md`
    file. The slicer only cares about `grid`, `cells`, and (for
    completeness) `animation_sequences`. The other sections (Function,
    Visual identity) flow through the composer untouched."""

    id: str
    front_matter: dict[str, str] = field(default_factory=dict)
    grid: tuple[int, int] = (0, 0)
    """Grid dimensions as (cols, rows). Matches the `## Sheet` line
    `Grid: N cols × M rows`."""
    cells: dict[tuple[int, int], str] = field(default_factory=dict)
    """Map of (row, col) → assignment. Assignment is either an atlas
    filename like `building-sawmill-operational-0` or the literal
    string `spare`."""
    animation_sequences: list[list[tuple[int, int]]] = field(default_factory=list)


def _split_sections(markdown: str) -> dict[str, str]:
    """Split a Markdown document by its `## Foo` headings. Returns a
    dict from heading text (e.g. `Sheet`) to the body following it.
    Front matter is stripped before splitting."""
    body = _FRONT_MATTER_RE.sub("", markdown, count=1)
    sections: dict[str, str] = {}
    matches = list(_HEADING_RE.finditer(body))
    for i, m in enumerate(matches):
        title = m.group(1).strip()
        start = m.end()
        end = matches[i + 1].start() if i + 1 < len(matches) else len(body)
        sections[title] = body[start:end]
    return sections


def _parse_front_matter(markdown: str) -> dict[str, str]:
    """Parse a tiny `key = "value"` YAML/TOML-ish front-matter block.
    No nesting, no lists. Quoted values only."""
    out: dict[str, str] = {}
    m = _FRONT_MATTER_RE.match(markdown)
    if not m:
        return out
    for raw in m.group(1).splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            continue
        key, _, value = line.partition("=")
        key = key.strip()
        value = value.strip()
        if (value.startswith('"') and value.endswith('"')) or (
            value.startswith("'") and value.endswith("'")
        ):
            value = value[1:-1]
        out[key] = value
    return out


def parse_catalog_entry(entry_id: str, markdown: str) -> CatalogEntry:
    """Parse a catalog entry's Markdown text into a `CatalogEntry`.

    Pure. No I/O.
    """
    front = _parse_front_matter(markdown)
    sections = _split_sections(markdown)
    sheet_body = sections.get("Sheet", "")

    grid: tuple[int, int] = (0, 0)
    grid_match = _GRID_RE.search(sheet_body)
    if grid_match:
        cols = int(grid_match.group(1))
        rows = int(grid_match.group(2))
        grid = (cols, rows)

    cells: dict[tuple[int, int], str] = {}
    for m in _CELL_ASSIGNMENT_RE.finditer(sheet_body):
        r = int(m.group(1))
        c = int(m.group(2))
        assignment = m.group(3) or m.group(4) or ""
        cells[(r, c)] = assignment.strip()

    animation_sequences: list[list[tuple[int, int]]] = []
    anim_body = sections.get("Animation", "")
    for raw in anim_body.splitlines():
        line = raw.strip()
        if "→" not in line and "->" not in line:
            continue
        coords = [
            (int(rs), int(cs))
            for rs, cs in _COORD_RE.findall(line)
        ]
        if len(coords) >= 2:
            animation_sequences.append(coords)

    return CatalogEntry(
        id=entry_id,
        front_matter=front,
        grid=grid,
        cells=cells,
        animation_sequences=animation_sequences,
    )


def slice_plan(entry: CatalogEntry) -> list[tuple[tuple[int, int], str]]:
    """Return the list of `((row, col), atlas_filename)` tuples for
    this catalog entry, in row-major order. Spare cells are skipped.

    Pure and deterministic — equal inputs ⇒ equal outputs in equal
    order.
    """
    out: list[tuple[tuple[int, int], str]] = []
    for coord in sorted(entry.cells.keys()):
        assignment = entry.cells[coord]
        if assignment == "spare":
            continue
        out.append((coord, assignment))
    return out


def slice_sheet(
    sheet: Image.Image,
    plan: Iterable[tuple[tuple[int, int], str]],
    grid: tuple[int, int],
    sheet_size: tuple[int, int],
) -> list[tuple[str, Image.Image]]:
    """Cut a generated sheet image into per-cell tiles using the slice
    plan. Returns a list of (filename, cell_image) pairs in plan order.

    Pure given a particular `sheet` image (no caching, no mutation
    of `sheet`)."""
    cols, rows = grid
    sheet_w, sheet_h = sheet_size
    if cols <= 0 or rows <= 0:
        return []
    cell_w = sheet_w // cols
    cell_h = sheet_h // rows
    out: list[tuple[str, Image.Image]] = []
    for (row, col), name in plan:
        left = col * cell_w
        upper = row * cell_h
        right = left + cell_w
        lower = upper + cell_h
        tile = sheet.crop((left, upper, right, lower))
        out.append((name, tile))
    return out
