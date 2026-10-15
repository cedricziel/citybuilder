"""Quantize a directory of raw RGBA renders into the atlases, then give legacy sprites their @2x twins.

usage: python -m art.finalize <raw-dir> <resources-dir>

SpriteKit loads only the @2x pages of an atlas on a retina device once the atlas has any @2x art,
so a 1x-only legacy sprite in that atlas disappears (the palette's sawmill icon went blank).
Every 1x sprite in such an atlas therefore gets a twin: kit renders ship their own; legacy pixel art
gets an exact nearest-neighbour 2x copy, which looks identical on screen.
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

from art import atlas


def finalize(raw: Path, resources: Path) -> list[Path]:
    """Writes `<resources>/<Atlas>.atlas/<file>` for every PNG in `raw`, then the legacy twins;
    returns the paths written."""
    written = []
    for source in sorted(raw.glob("*.png")):
        dest = atlas.atlas_path(resources, source.name)
        with Image.open(source) as image:
            atlas.save_indexed(image, dest)
        written.append(dest)
    rendered = {path.name for path in raw.glob("*.png")}
    return written + fill_scale_twins(resources, rendered)


def fill_scale_twins(resources: Path, rendered: set[str] = frozenset()) -> list[Path]:
    """In every atlas holding @2x art, (re)write the nearest-neighbour twin of each 1x sprite that the
    art kit did not render this run. Rewriting every time keeps twins in step with their 1x sprite."""
    written = []
    for atlas_dir in sorted(resources.glob("*.atlas")):
        if not any(atlas_dir.glob("*@2x.png")):
            continue
        for one_x in sorted(atlas_dir.glob("*.png")):
            twin_name = f"{one_x.stem}@2x.png"
            if "@" in one_x.stem or twin_name in rendered:
                continue
            twin = atlas_dir / twin_name
            with Image.open(one_x) as image:
                doubled = image.resize((image.width * 2, image.height * 2), Image.NEAREST)
                save_exact(doubled, twin)
            written.append(twin)
    return written


def save_exact(image: Image.Image, dest: Path) -> None:
    """An indexed image keeps its palette (no re-quantization), so the twin's pixels are exactly the 1x pixels."""
    if image.mode == "P":
        tmp = dest.with_name(f".{dest.name}.tmp")
        image.save(tmp, format="PNG", optimize=True)
        tmp.chmod(0o644)
        tmp.replace(dest)
    else:
        atlas.save_indexed(image, dest)


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    written = finalize(Path(argv[0]), Path(argv[1]))
    print(f"[art.finalize] {len(written)} atlas PNG(s) written")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
