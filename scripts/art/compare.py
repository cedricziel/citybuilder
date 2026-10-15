"""Compare fresh raw renders with the committed atlas PNGs, within a tolerance (design D5).

Committed PNGs are 256-colour indexed (design D8), so a fresh render never matches them byte for
byte: quantization error dominates (up to ~0.7/255 mean on the Kit-proof sprites) and GPU noise
adds almost nothing (~0.002/255). The fresh RGBA render is therefore compared with the decoded
committed PNG, both premultiplied so fully transparent pixels compare equal whatever their RGB.

A PNG fails when its mean absolute channel difference exceeds MAX_MEAN_DIFF (0-255 units), or when
more than MAX_OUTLIER_FRACTION of its pixels differ by more than OUTLIER_DELTA in any channel.

usage: python -m art.compare <raw-dir> <resources-dir>
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageChops

from art import atlas

MAX_MEAN_DIFF = 1.5
OUTLIER_DELTA = 24
MAX_OUTLIER_FRACTION = 0.003


def premultiplied(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    rgb = ImageChops.multiply(rgba.convert("RGB"), Image.merge("RGB", (alpha, alpha, alpha)))
    return Image.merge("RGBA", (*rgb.split(), alpha))


def difference(fresh: Image.Image, committed: Image.Image) -> tuple[float, float]:
    """(mean absolute channel difference, fraction of pixels with a channel off by > OUTLIER_DELTA)."""
    diff = ImageChops.difference(premultiplied(fresh), premultiplied(committed))
    pixels = diff.width * diff.height
    histogram = diff.histogram()  # 4 channels x 256 bins
    total = sum(value * count for channel in range(4) for value, count in enumerate(histogram[channel * 256:(channel + 1) * 256]))
    bands = diff.split()
    worst = bands[0]
    for band in bands[1:]:
        worst = ImageChops.lighter(worst, band)
    outliers = sum(worst.histogram()[OUTLIER_DELTA + 1:])
    return total / (pixels * 4), outliers / pixels


def compare_trees(raw_dir: Path, resources: Path) -> list[str]:
    """One message per raw render outside tolerance of its committed atlas PNG; empty when all pass."""
    failures = []
    for fresh_path in sorted(raw_dir.glob("*.png")):
        committed_path = atlas.atlas_path(resources, fresh_path.name)
        rel = committed_path.relative_to(resources)
        if not committed_path.exists():
            failures.append(f"{rel}: rendered but not committed")
            continue
        with Image.open(fresh_path) as fresh, Image.open(committed_path) as committed:
            if fresh.size != committed.size:
                failures.append(f"{rel}: size {fresh.size} differs from committed {committed.size}")
                continue
            mean, outliers = difference(fresh, committed)
        if mean > MAX_MEAN_DIFF or outliers > MAX_OUTLIER_FRACTION:
            failures.append(f"{rel}: mean diff {mean:.3f}/255, {outliers * 100:.3f}% of pixels off by > {OUTLIER_DELTA}")
    return failures


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    raw_dir = Path(argv[0])
    failures = compare_trees(raw_dir, Path(argv[1]))
    for failure in failures:
        print(failure)
    print(f"[art.compare] {len(list(raw_dir.glob('*.png')))} render(s) checked, {len(failures)} outside tolerance")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
