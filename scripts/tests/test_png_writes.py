"""`cache._save_indexed` replaces a PNG atomically (see its comment)."""

from __future__ import annotations

from pathlib import Path

from PIL import Image

from generate_sprites_ai import cache


def _image(colour: tuple[int, int, int, int]) -> Image.Image:
    return Image.new("RGBA", (16, 16), colour)


def test_reader_of_the_old_png_keeps_its_complete_bytes(tmp_path: Path) -> None:
    dest = tmp_path / "sprite.png"
    cache._save_indexed(_image((255, 0, 0, 255)), dest)
    old_bytes = dest.read_bytes()

    with dest.open("rb") as reader:
        cache._save_indexed(_image((0, 0, 255, 255)), dest)
        seen = reader.read()

    assert seen == old_bytes
    assert dest.read_bytes() != old_bytes


def test_write_leaves_no_temporary_file(tmp_path: Path) -> None:
    cache._save_indexed(_image((0, 255, 0, 255)), tmp_path / "sprite.png")

    assert [p.name for p in tmp_path.iterdir()] == ["sprite.png"]
