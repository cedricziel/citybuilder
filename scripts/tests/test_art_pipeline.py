"""The `make sprites` contract (sprite-asset-pipeline, replace-generative-sprites-with-isokit)."""

from __future__ import annotations

import re
from pathlib import Path

import pytest

from art import svg_sprites

REPO = Path(__file__).resolve().parents[2]


def _recipe(target: str) -> str:
    """The recipe lines of a Makefile target."""
    makefile = (REPO / "Makefile").read_text(encoding="utf-8")
    match = re.search(rf"^{re.escape(target)}:.*\n((?:\t.*\n)+)", makefile, re.MULTILINE)
    assert match, f"no {target} target"
    return match.group(1)


@pytest.mark.scenario("make sprites runs offline")
def test_make_sprites_runs_offline() -> None:
    recipe = _recipe("sprites")
    assert "isokit) render" in recipe or "$(ISOKIT) render" in recipe
    assert "art.svg_sprites" in recipe
    assert "art.finalize" in recipe
    assert "generate_sprites_ai" not in recipe
    assert "OPENAI" not in recipe


@pytest.mark.scenario("Every atlas PNG has a recipe or an SVG source")
def test_every_svg_entry_has_a_source() -> None:
    """SVG-sourced briefs name only sprites the generators can draw. (IsoKit-sourced briefs are
    checked against the recipe registry by Tools/IsoKit's tests.)"""
    wanted = svg_sprites.svg_entry_names(REPO / "Resources/Sprites.style/catalog")
    drawable = svg_sprites.drawable_names()
    missing = [name for name in wanted if name not in drawable]
    assert missing == []


def test_verify_never_byte_compares_art() -> None:
    recipe = _recipe("sprites-art-verify")
    assert "art.compare" in recipe
    assert "cmp " not in recipe and "shasum" not in recipe
