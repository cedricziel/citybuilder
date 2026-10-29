"""Building status icons are hand-authored SVG (change add-building-status-icons)."""

from __future__ import annotations

import xml.etree.ElementTree as ET
from pathlib import Path

from art import goods_icons, status_icons, svg_sprites

REPO = Path(__file__).resolve().parents[2]
CATALOG = REPO / "Resources/Sprites.style/catalog"


def test_every_good_has_a_short_and_a_stuck_icon() -> None:
    names = set(status_icons.sources())
    for good in goods_icons.GLYPHS:
        assert f"status-{good}-short" in names
        assert f"status-{good}-stuck" in names


def test_every_issue_pictogram_is_drawn() -> None:
    names = set(status_icons.sources())
    for pictogram in ("no-road", "no-route", "no-trees", "no-room-to-plant"):
        assert f"status-{pictogram}" in names


def test_icons_are_well_formed_28_point_svg_with_the_goods_outline() -> None:
    for name, svg in status_icons.sources().items():
        root = ET.fromstring(svg)
        assert root.get("viewBox") == "0 0 28 28", name
        strokes = {element.get("stroke") for element in root.iter()}
        assert status_icons.OUTLINE in strokes, f"{name} has no outline"


def test_the_brief_lists_every_icon_and_is_drawn_as_svg() -> None:
    brief = CATALOG / "status-icons.md"
    text = brief.read_text(encoding="utf-8")
    assert 'source = "svg"' in text
    assert svg_sprites.sprite_names(text, brief.stem) == sorted(status_icons.sources())
    assert set(status_icons.sources()) <= svg_sprites.drawable_names()


def test_seasonal_event_icons_are_drawn() -> None:
    """add-event-counterplay: a burning building, ruins to clear, a blighted field, a fevered house."""
    names = set(status_icons.sources())
    for icon in ("burning", "ruins", "blight", "fever"):
        assert f"status-{icon}" in names
