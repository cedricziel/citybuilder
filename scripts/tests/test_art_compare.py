"""Tolerance check of fresh renders against the committed atlases (design D5)."""

from __future__ import annotations

import random
from pathlib import Path

import pytest
from PIL import Image

from art import atlas, compare


def _sprite(roof: tuple[int, int, int, int] = (170, 70, 45, 255)) -> Image.Image:
    """A shaded 'building' with a soft shadow edge, so quantization has real work to do."""
    image = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    for y in range(8, 60):
        for x in range(8, 56):
            shade = (x + y) % 23
            colour = roof if y < 30 else (200 - shade, 170 - shade, 130 - shade, 255)
            image.putpixel((x, y), colour)
    for x in range(56, 62):
        image.putpixel((x, 40), (20, 12, 6, 90))  # translucent shadow
    return image


def _commit(resources: Path, name: str, image: Image.Image) -> None:
    atlas.save_indexed(image, atlas.kit_path(resources, name))


@pytest.mark.scenario("Unchanged recipes pass verification")
def test_unchanged_renders_pass(tmp_path: Path) -> None:
    resources, raw = tmp_path / "Resources", tmp_path / "raw"
    raw.mkdir()
    _commit(resources, "building-house.png", _sprite())
    noisy = _sprite()
    rng = random.Random(1)
    for _ in range(3):  # GPU noise: a few pixels off by a little
        x, y = rng.randrange(8, 56), rng.randrange(8, 60)
        r, g, b, a = noisy.getpixel((x, y))
        noisy.putpixel((x, y), (min(r + 6, 255), g, b, a))
    noisy.save(raw / "building-house.png")
    assert compare.compare_trees(raw, resources) == []


@pytest.mark.scenario("A changed recipe without re-rendered PNGs fails verification")
def test_changed_render_fails_and_names_the_png(tmp_path: Path) -> None:
    resources, raw = tmp_path / "Resources", tmp_path / "raw"
    raw.mkdir()
    _commit(resources, "building-house.png", _sprite())
    _sprite((60, 60, 70, 255)).save(raw / "building-house.png")  # roof finish changed to slate
    failures = compare.compare_trees(raw, resources)
    assert len(failures) == 1
    assert "Kit.atlas/building-house.png" in failures[0]


def test_transparent_pixels_compare_equal_whatever_their_rgb(tmp_path: Path) -> None:
    clear_red = Image.new("RGBA", (8, 8), (255, 0, 0, 0))
    clear_black = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
    assert compare.difference(clear_red, clear_black) == (0.0, 0.0)


def test_missing_committed_png_fails(tmp_path: Path) -> None:
    raw = tmp_path / "raw"
    raw.mkdir()
    _sprite().save(raw / "building-house.png")
    failures = compare.compare_trees(raw, tmp_path / "Resources")
    assert failures and "not committed" in failures[0]


def test_size_change_fails(tmp_path: Path) -> None:
    resources, raw = tmp_path / "Resources", tmp_path / "raw"
    raw.mkdir()
    _commit(resources, "building-house.png", _sprite())
    _sprite().resize((64, 80)).save(raw / "building-house.png")
    assert "size" in compare.compare_trees(raw, resources)[0]


def test_tolerance_numbers_match_the_spec() -> None:
    assert compare.MAX_MEAN_DIFF == 1.5
    assert compare.OUTLIER_DELTA == 24
    assert compare.MAX_OUTLIER_FRACTION == 0.003
