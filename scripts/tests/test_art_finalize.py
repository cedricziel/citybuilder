"""Raw renders become indexed atlas PNGs (design D8)."""

from __future__ import annotations

from pathlib import Path

import pytest
from PIL import Image

from art import atlas, finalize


def test_routes_by_prefix() -> None:
    assert atlas.atlas_name("building-house@2x.png") == "Buildings"
    assert atlas.atlas_name("overlay-waiting-materials.png") == "Buildings"
    assert atlas.atlas_name("terrain-grass-beach-t3.png") == "Terrain"
    assert atlas.atlas_name("walker-se-0.png") == "Units"
    assert atlas.atlas_name("ship-n-0.png") == "Units"
    assert atlas.atlas_name("good-wood.png") == "Icons"
    with pytest.raises(ValueError):
        atlas.atlas_name("mystery.png")


def test_finalize_writes_indexed_pngs_into_atlases(tmp_path: Path) -> None:
    raw, resources = tmp_path / "raw", tmp_path / "Resources"
    raw.mkdir()
    Image.new("RGBA", (128, 112), (120, 80, 50, 255)).save(raw / "building-house.png")
    Image.new("RGBA", (256, 224), (120, 80, 50, 255)).save(raw / "building-house@2x.png")
    Image.new("RGBA", (64, 32), (90, 140, 60, 255)).save(raw / "terrain-grass-beach-t3.png")
    written = finalize.finalize(raw, resources)
    assert sorted(p.relative_to(resources).as_posix() for p in written) == [
        "Buildings.atlas/building-house.png",
        "Buildings.atlas/building-house@2x.png",
        "Terrain.atlas/terrain-grass-beach-t3.png",
    ]
    for path in written:
        assert Image.open(path).mode == "P"


def test_legacy_sprites_in_an_atlas_with_2x_art_get_exact_twins(tmp_path: Path) -> None:
    """SpriteKit loads only the @2x pages once an atlas has any; 1x-only sprites would vanish."""
    raw, resources = tmp_path / "raw", tmp_path / "Resources"
    raw.mkdir()
    Image.new("RGBA", (128, 112), (120, 80, 50, 255)).save(raw / "building-house.png")
    Image.new("RGBA", (256, 224), (120, 80, 50, 255)).save(raw / "building-house@2x.png")
    legacy = Image.new("RGBA", (4, 3), (0, 0, 0, 0))
    legacy.putpixel((1, 1), (200, 20, 20, 255))
    atlas.save_indexed(legacy, resources / "Buildings.atlas" / "building-sawmill.png")
    atlas.save_indexed(legacy, resources / "Terrain.atlas" / "terrain-grass.png")  # no @2x art there

    finalize.finalize(raw, resources)

    twin = Image.open(resources / "Buildings.atlas" / "building-sawmill@2x.png").convert("RGBA")
    one = Image.open(resources / "Buildings.atlas" / "building-sawmill.png").convert("RGBA")
    assert twin.size == (8, 6)
    assert all(twin.getpixel((x, y)) == one.getpixel((x // 2, y // 2)) for x in range(8) for y in range(6))
    assert not (resources / "Terrain.atlas" / "terrain-grass@2x.png").exists()
    kit_twin = Image.open(resources / "Buildings.atlas" / "building-house@2x.png")
    assert kit_twin.size == (256, 224)  # the kit's own render, not a nearest copy of its 1x


def test_finalize_with_nothing_to_do_writes_nothing(tmp_path: Path) -> None:
    raw = tmp_path / "raw"
    raw.mkdir()
    assert finalize.finalize(raw, tmp_path / "Resources") == []
    assert not (tmp_path / "Resources").exists()


def test_alpha_survives_quantization(tmp_path: Path) -> None:
    image = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    image.putpixel((3, 3), (200, 100, 50, 255))
    dest = tmp_path / "Buildings.atlas" / "building-x.png"
    atlas.save_indexed(image, dest)
    back = Image.open(dest).convert("RGBA")
    assert back.getpixel((0, 0))[3] == 0
    assert back.getpixel((3, 3))[3] == 255
