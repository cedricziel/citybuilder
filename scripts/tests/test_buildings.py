"""Tests for the procedural building kit (`generate_sprites_ai.buildings`)
and the unit renderers. Spec: openspec/changes/unify-art-style."""

from __future__ import annotations

import pytest

from generate_sprites_ai.batcher import PALETTE
from generate_sprites_ai.buildings import FOOTPRINTS, Projector
from generate_sprites_ai.procedural import render, render_sheet, size, supported
from generate_sprites_ai.postprocess import downsample

OUTLINE = (0x1A, 0x14, 0x10)

KINDS = ["house", "warehouse", "lumberjack-hut", "sawmill", "town-center",
         *[f"port-{o}" for o in "nesw"], *[f"shipyard-{o}" for o in "nesw"]]
OPERATIONAL = {"lumberjack-hut": 2, "sawmill": 4, "town-center": 2,
               **{f"port-{o}": 2 for o in "nesw"}, **{f"shipyard-{o}": 2 for o in "nesw"}}
UNITS = [f"walker-{d}-{f}" for d in ("ne", "se", "sw", "nw") for f in (0, 1)] + \
        [f"ship-{d}-{f}" for d in ("n", "ne", "e", "se", "s", "sw", "w", "nw") for f in (0, 1)]


@pytest.mark.parametrize("w,h", [(2, 2), (3, 3), (2, 3)])
def test_projector_puts_the_bottom_vertex_on_the_last_row(w: int, h: int) -> None:
    proj = Projector(w, h, extra=40)
    x, y = proj.p(w, h)
    # The canvas is centred on the diamond; its bottom row is the bottom vertex.
    assert (x, y) == (proj.width / 2 + (w - h) * 16, proj.height)
    assert proj.width == (w + h) * 32


def test_every_building_and_unit_is_supported() -> None:
    names = set(supported())
    for kind in KINDS:
        assert f"building-{kind}" in names
        for i in range(3):
            assert f"building-{kind}-constructing-{i}" in names
        for i in range(OPERATIONAL.get(kind, 0)):
            assert f"building-{kind}-operational-{i}" in names
    assert set(UNITS) <= names


@pytest.mark.parametrize("kind", KINDS)
def test_building_canvas_matches_its_footprint(kind: str) -> None:
    w, h = FOOTPRINTS[kind]
    assert render(f"building-{kind}").size[0] == (w + h) * 32


@pytest.mark.parametrize("kind", KINDS)
def test_building_base_uses_outline_and_sits_on_the_canvas_bottom(kind: str) -> None:
    img = render(f"building-{kind}")
    pixels = [p for p in img.getdata() if p[3]]
    share = sum(1 for p in pixels if p[:3] == OUTLINE) / len(pixels)
    assert share >= 0.03, (kind, share)
    assert img.getbbox()[3] == img.size[1]


@pytest.mark.parametrize("kind", KINDS)
def test_construction_stages_grow(kind: str) -> None:
    counts = [
        sum(1 for p in render(f"building-{kind}-constructing-{i}").getdata() if p[3])
        for i in range(3)
    ]
    full = sum(1 for p in render(f"building-{kind}").getdata() if p[3])
    assert counts[0] < counts[2] <= full, (kind, counts, full)


@pytest.mark.parametrize("name", [f"building-{k}" for k in KINDS] + UNITS)
def test_sprites_stay_in_palette_with_binary_alpha(name: str) -> None:
    palette = set(PALETTE)
    for r, g, b, a in render(name).getdata():
        assert a in (0, 255)
        if a:
            assert (r, g, b) in palette, name


def test_unit_canvas_sizes() -> None:
    assert render("walker-se-0").size == (8, 12)
    assert render("ship-e-0").size == (32, 16)


def test_unit_frames_animate() -> None:
    assert render("walker-se-0").tobytes() != render("walker-se-1").tobytes()
    assert render("ship-n-0").tobytes() != render("ship-n-1").tobytes()


def test_size_reports_render_size_and_sheets_round_trip() -> None:
    for name in ("building-port-e", "building-town-center", "walker-nw-1", "terrain-water"):
        assert size(name) == render(name).size
        sheet = render_sheet(name)
        assert downsample(sheet, size(name)).tobytes() == render(name).tobytes()


@pytest.mark.parametrize("kind", KINDS)
def test_canvas_headroom_is_trimmed_to_the_smoke_plume(kind: str) -> None:
    """Badges float just above the sprite's top edge, so the canvas
    keeps only room for the smoke plume above the roof."""
    top = render(f"building-{kind}").getbbox()[1]
    assert top <= 14, (kind, top)
