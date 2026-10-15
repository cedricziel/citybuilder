"""Render SVG-sourced sprites (terrain, transitions, roads, icons) to raw RGBA PNGs with rsvg-convert.

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

from art import roads, terrain_tiles

SHEET_LINE = re.compile(r"^- \(\d+, *\d+\): `([a-z0-9-]+)`", re.MULTILINE)
SOURCE_LINE = re.compile(r'^source\s*=\s*"([a-z]+)"', re.MULTILINE)


def all_sources() -> dict[str, str]:
    return {**terrain_tiles.sources(), **roads.sources()}


def svg_entry_names(catalog: Path) -> list[str]:
    """Sprite names declared by catalog entries whose front matter says `source = "svg"`."""
    names = []
    for md in sorted(catalog.glob("*.md")):
        text = md.read_text(encoding="utf-8")
        front = text.split("---")[1] if text.startswith("---") else ""
        match = SOURCE_LINE.search(front)
        if match and match.group(1) == "svg":
            names += SHEET_LINE.findall(text) or [md.stem]
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
    sources = all_sources()
    if not args.all:
        wanted = svg_entry_names(args.catalog)
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
