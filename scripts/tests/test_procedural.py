"""Tests for `generate_sprites_ai.procedural`: locally drawn sprites
for catalog entries marked `source = "procedural"`."""

from __future__ import annotations

import pytest
from PIL import Image

from generate_sprites_ai.batcher import PALETTE
from generate_sprites_ai.postprocess import downsample, in_diamond
from generate_sprites_ai.procedural import SHEET_SIZE, render, render_sheet, supported

TERRAIN = [
    "terrain-grass", "terrain-grass-0", "terrain-grass-1",
    "terrain-forest",
    "terrain-beach", "terrain-beach-0", "terrain-beach-1",
    "terrain-mountain", "terrain-mountain-v1", "terrain-mountain-v2", "terrain-mountain-v3",
    "terrain-water", "terrain-water-0", "terrain-water-1", "terrain-water-2", "terrain-water-3",
]


def test_every_terrain_sprite_is_supported() -> None:
    assert set(TERRAIN) <= set(supported())


@pytest.mark.parametrize("name", TERRAIN)
def test_terrain_sprite_fills_the_diamond_and_nothing_else(name: str) -> None:
    img = render(name)
    assert img.size == (64, 32)
    for y in range(32):
        for x in range(64):
            opaque = img.getpixel((x, y))[3] == 255
            assert opaque == in_diamond(x, y, 64, 32), (name, x, y)


@pytest.mark.parametrize("name", TERRAIN)
def test_terrain_sprite_uses_only_palette_colours(name: str) -> None:
    palette = set(PALETTE)
    for r, g, b, a in render(name).getdata():
        if a:
            assert (r, g, b) in palette, name


def test_rendering_is_deterministic() -> None:
    for name in TERRAIN:
        assert render(name).tobytes() == render(name).tobytes()


def test_water_frames_differ_from_each_other() -> None:
    frames = {render(f"terrain-water-{i}").tobytes() for i in range(4)}
    assert len(frames) == 4


def test_mountain_variants_differ_from_the_base() -> None:
    base = render("terrain-mountain").tobytes()
    for v in (1, 2, 3):
        assert render(f"terrain-mountain-v{v}").tobytes() != base


def test_sheet_round_trips_through_nearest_downsample() -> None:
    """The pipeline downsamples the 1024×1024 sheet with nearest-
    neighbour; the result must equal the canonical sprite exactly."""
    for name in ("terrain-water-1", "terrain-forest"):
        sheet = render_sheet(name)
        assert sheet.size == (SHEET_SIZE, SHEET_SIZE)
        assert downsample(sheet, (64, 32)).tobytes() == render(name).tobytes()


def test_unknown_sprite_raises() -> None:
    with pytest.raises(KeyError):
        render("terrain-lava")
