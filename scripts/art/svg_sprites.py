"""Render SVG-sourced sprites (terrain, transitions, roads, goods icons) to raw RGBA PNGs with rsvg-convert.

usage: python -m art.svg_sprites --catalog <dir> --out <dir> [--all]

Only catalog entries with `source = "svg"` are rendered, unless --all (every known source, for
a scratch directory). `art.finalize` quantizes the output into the atlases.
"""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from art import goods_icons, roads, terrain_objects, terrain_tiles

SPRITE_LINE = re.compile(r"^- `([a-z0-9-]+)`")  # the grammar IsoKit's `Catalog` and the gate read
SOURCE_LINE = re.compile(r'^source\s*=\s*"([a-z]+)"', re.MULTILINE)


def all_sources(wanted: set[str] | None = None) -> dict[str, str]:
    """Every SVG source, or every tile, road and goods icon plus the `wanted` terrain objects:
    objects are ray-cast, so only the ones asked for are drawn."""
    return {**terrain_tiles.sources(), **roads.sources(), **goods_icons.sources(), **terrain_objects.sources(wanted)}


def drawable_names() -> set[str]:
    """Every sprite name an SVG source exists for, without ray-casting any object."""
    return {*terrain_tiles.sources(), *roads.sources(), *goods_icons.sources(), *terrain_objects.names()}


class UnreadableBrief(ValueError):
    """A brief whose `## Sprites` list cannot be read."""


def sprite_names(text: str, brief: str) -> list[str]:
    """The names in a brief's `## Sprites` section, in order. A brief with no Sprites section, an empty
    one, or a name outside `[a-z0-9-]` is an error, so no brief's sprites drop out unnoticed."""
    lines = [line.strip() for line in text.splitlines()]
    if "## Sprites" not in lines:
        raise UnreadableBrief(f"{brief}: no `## Sprites` section")
    names = []
    for line in lines[lines.index("## Sprites") + 1 :]:
        if line.startswith("## "):
            break
        if not line.startswith("- "):
            continue
        match = SPRITE_LINE.match(line)
        if not match:
            raise UnreadableBrief(f"{brief}: sprite line is not `- `name``: {line}")
        names.append(match.group(1))
    if not names:
        raise UnreadableBrief(f"{brief}: its Sprites section lists no sprite")
    return names


def svg_entry_names(catalog: Path) -> list[str]:
    """Sprite names declared by catalog entries whose front matter says `source = "svg"`."""
    names = []
    for md in sorted(catalog.glob("*.md")):
        text = md.read_text(encoding="utf-8")
        front = text.split("---")[1] if text.startswith("---") else ""
        match = SOURCE_LINE.search(front)
        if match and match.group(1) == "svg":
            names += sprite_names(text, md.stem)
    return names


def render_sources(sources: dict[str, str], out: Path, scales: tuple[int, ...] = (1, 2)) -> list[Path]:
    if sources and shutil.which("rsvg-convert") is None:
        raise SystemExit("rsvg-convert not found: install it with `brew install librsvg`")
    out.mkdir(parents=True, exist_ok=True)
    written = []
    with tempfile.TemporaryDirectory() as tmp:
        for name, svg in sorted(sources.items()):
            source = Path(tmp) / f"{name}.svg"
            source.write_text(svg, encoding="utf-8")
            for scale in scales:
                dest = out / (f"{name}.png" if scale == 1 else f"{name}@{scale}x.png")
                subprocess.run(["rsvg-convert", "-z", str(scale), str(source), "-o", str(dest)], check=True)
                written.append(dest)
    return written


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="art.svg_sprites")
    parser.add_argument("--catalog", type=Path, default=Path("Resources/Sprites.style/catalog"))
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--all", action="store_true")
    args = parser.parse_args(argv)
    wanted = None if args.all else svg_entry_names(args.catalog)
    sources = all_sources(None if wanted is None else set(wanted))
    if wanted is not None:
        missing = [name for name in wanted if name not in sources]
        if missing:
            print(f"[art.svg_sprites] no SVG source for: {', '.join(missing)}", file=sys.stderr)
            return 1
        sources = {name: sources[name] for name in wanted}
    written = render_sources(sources, args.out)
    print(f"[art.svg_sprites] {len(written)} file(s) from {len(sources)} source(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
