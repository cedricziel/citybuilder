"""Quantize a directory of raw RGBA renders into the atlases.

usage: python -m art.finalize <raw-dir> <resources-dir>
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

from art import atlas


def finalize(raw: Path, resources: Path) -> list[Path]:
    """Writes `<resources>/<Atlas>.atlas/<file>` for every PNG in `raw`; returns the paths written."""
    written = []
    for source in sorted(raw.glob("*.png")):
        dest = atlas.atlas_path(resources, source.name)
        with Image.open(source) as image:
            atlas.save_indexed(image, dest)
        written.append(dest)
    return written


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    written = finalize(Path(argv[0]), Path(argv[1]))
    print(f"[art.finalize] {len(written)} atlas PNG(s) written")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
