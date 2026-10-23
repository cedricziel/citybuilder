"""Goods icons are hand-authored SVG, one per good (issue #195)."""

from __future__ import annotations

import re
import xml.etree.ElementTree as ET
from pathlib import Path

from art import goods_icons, svg_sprites

REPO = Path(__file__).resolve().parents[2]
CATALOG = REPO / "Resources/Sprites.style/catalog"


def _game_goods() -> set[str]:
    """The goods CityCore knows, by raw value (`teaLeaves` is `tea-leaves`)."""
    source = (REPO / "Packages/CityCore/Sources/CityCore/Generated/Good+Generated.swift").read_text(encoding="utf-8")
    cases = re.findall(r"^\s*case (\w+)(?: = \"([a-z-]+)\")?$", source, re.MULTILINE)
    return {raw or name for name, raw in cases}


def test_every_good_has_an_icon() -> None:
    assert {f"good-{good}" for good in _game_goods()} == set(goods_icons.sources())


def test_every_goods_brief_is_drawn_as_svg() -> None:
    briefs = sorted(CATALOG.glob("good-*.md"))
    assert len(briefs) == len(goods_icons.GLYPHS)
    drawn = set(svg_sprites.svg_entry_names(CATALOG))
    for brief in briefs:
        assert 'source = "svg"' in brief.read_text(encoding="utf-8"), brief.name
        assert brief.stem in drawn


def test_icons_are_well_formed_24_point_svg() -> None:
    for name, svg in goods_icons.sources().items():
        root = ET.fromstring(svg)
        assert root.get("viewBox") == "0 0 24 24", name
        colours = {element.get("fill") for element in root} | {element.get("stroke") for element in root}
        assert goods_icons.OUTLINE in colours, f"{name} has no outline"


def test_every_role_has_a_colour() -> None:
    for good, shapes in goods_icons.GLYPHS.items():
        palette = goods_icons.colours(good)
        for _, _, role, kind in shapes:
            assert role in palette, f"{good}: {role}"
            assert kind in ("fill", "stroke")
