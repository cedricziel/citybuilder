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


FARM = [
    "building-farm",
    "building-farm-constructing-0", "building-farm-constructing-1", "building-farm-constructing-2",
    "building-farm-operational-0", "building-farm-operational-1",
]


def test_every_farm_sprite_is_supported() -> None:
    assert set(FARM) <= set(supported())


@pytest.mark.parametrize("name", FARM)
def test_farm_sprite_is_a_building_canvas_in_palette(name: str) -> None:
    img = render(name)
    assert img.size == (128, 128)
    palette = set(PALETTE)
    for r, g, b, a in img.getdata():
        assert a in (0, 255), name
        if a:
            assert (r, g, b) in palette, name


@pytest.mark.parametrize("name", FARM)
def test_farm_field_covers_the_footprint_diamond(name: str) -> None:
    """The 2×2 footprint diamond occupies the canvas's bottom 64 rows;
    the field must fill it so the farm sits flush on its tiles."""
    img = render(name)
    inside = [
        img.getpixel((x, y + 64))[3]
        for y in range(64) for x in range(128)
        if in_diamond(x, y, 128, 64)
    ]
    assert sum(1 for a in inside if a) / len(inside) >= 0.95, name


def test_farm_operational_frames_animate() -> None:
    assert render("building-farm-operational-0").tobytes() != render("building-farm-operational-1").tobytes()


def test_farm_sheet_round_trips() -> None:
    sheet = render_sheet("building-farm")
    assert downsample(sheet, (128, 128)).tobytes() == render("building-farm").tobytes()


# ---------------- derived operational frames ----------------

from generate_sprites_ai.procedural import derive_operational  # noqa: E402


def _house_like() -> Image.Image:
    img = Image.new("RGBA", (128, 106), (0, 0, 0, 0))
    for y in range(30, 90):
        for x in range(30, 100):
            img.putpixel((x, y), (*PALETTE[10], 255))
    return img


def test_derived_frames_keep_the_building_pixels() -> None:
    """Every opaque pixel of the base survives unchanged except where
    smoke is drawn above the roof line."""
    base = _house_like()
    for i in range(4):
        frame = derive_operational(base, i, 4)
        assert frame.size == base.size
        for y in range(40, 106):
            for x in range(128):
                assert frame.getpixel((x, y)) == base.getpixel((x, y))


def test_derived_frames_keep_left_right_bottom_edges() -> None:
    base = _house_like()
    _, _, br, bb = base.getbbox()
    bl = base.getbbox()[0]
    for i in range(4):
        left, _, right, bottom = derive_operational(base, i, 4).getbbox()
        assert abs(left - bl) <= 2 and abs(right - br) <= 2 and bottom == bb


def test_derived_frames_differ_and_stay_in_palette() -> None:
    base = _house_like()
    frames = [derive_operational(base, i, 2) for i in range(2)]
    assert frames[0].tobytes() != frames[1].tobytes()
    palette = set(PALETTE)
    for f in frames:
        for r, g, b, a in f.getdata():
            assert a in (0, 255)
            if a:
                assert (r, g, b) in palette
