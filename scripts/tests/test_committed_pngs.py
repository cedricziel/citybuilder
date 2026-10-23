"""Committed atlas PNGs are indexed, and the art pipeline writes them that way."""

from __future__ import annotations

from pathlib import Path

import pytest
from PIL import Image

from art import atlas

RESOURCES = Path(__file__).resolve().parents[2] / "Resources"


@pytest.mark.scenario("Every committed sprite PNG is indexed-mode")
def test_every_committed_atlas_png_is_indexed() -> None:
    pngs = sorted(RESOURCES.glob("*.atlas/*.png"))
    assert len(pngs) > 300
    truecolor = [p.relative_to(RESOURCES).as_posix() for p in pngs if Image.open(p).mode != "P"]
    assert truecolor == []


@pytest.mark.scenario("Pipeline writes indexed-mode PNGs by default")
def test_the_art_pipeline_writes_indexed_pngs(tmp_path: Path) -> None:
    dest = tmp_path / "Kit.atlas" / "building-test.png"
    atlas.save_indexed(Image.new("RGBA", (16, 16), (200, 120, 60, 255)), dest)
    assert Image.open(dest).mode == "P"
