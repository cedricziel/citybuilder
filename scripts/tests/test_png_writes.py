"""PNG writes replace the file atomically.

`make sprites-verify` reads the committed atlas PNGs while another
process (the CityRender2D test that runs `make sprites-offline`) may be
rewriting the same files. A write that truncates the file in place lets
that reader see a partial PNG. Writing to a temporary file and renaming
it over the destination means a reader sees either the old file or the
new one, never a mix.
"""

from __future__ import annotations

from pathlib import Path

import pytest
from PIL import Image

from generate_sprites_ai import cache


# The atlas, sheet, cache and master-reference writers all go through
# `cache._save_indexed`.
WRITERS = [pytest.param(cache._save_indexed, id="cache._save_indexed")]


def _image(colour: tuple[int, int, int, int]) -> Image.Image:
    return Image.new("RGBA", (16, 16), colour)


@pytest.mark.parametrize("write", WRITERS)
def test_reader_of_the_old_png_keeps_its_complete_bytes(write, tmp_path: Path) -> None:
    dest = tmp_path / "sprite.png"
    write(_image((255, 0, 0, 255)), dest)
    old_bytes = dest.read_bytes()

    with dest.open("rb") as reader:
        write(_image((0, 0, 255, 255)), dest)
        seen = reader.read()

    assert seen == old_bytes
    assert dest.read_bytes() != old_bytes


@pytest.mark.parametrize("write", WRITERS)
def test_write_leaves_no_temporary_file(write, tmp_path: Path) -> None:
    write(_image((0, 255, 0, 255)), tmp_path / "sprite.png")

    assert [p.name for p in tmp_path.iterdir()] == ["sprite.png"]
