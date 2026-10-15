"""Terrain transition tiles (capability `iso-art-kit`, design D6)."""

from __future__ import annotations

import shutil
from pathlib import Path

import pytest
from PIL import Image

from art import svg_sprites, terrain_tiles

needs_rsvg = pytest.mark.skipif(shutil.which("rsvg-convert") is None, reason="rsvg-convert not installed")


@pytest.mark.scenario("Both transition sets are complete")
def test_both_transition_sets_are_complete() -> None:
    names = set(terrain_tiles.sources())
    for pair in ("grass-beach", "beach-water"):
        for mask in range(1, 15):
            assert f"terrain-{pair}-t{mask}" in names
    assert "terrain-grass-beach-t15" not in names
    assert "terrain-grass-beach-t0" not in names


def test_boundary_meets_edges_at_midpoints() -> None:
    """Every interior curve starts and ends on an edge midpoint, pushed out by the bleed."""
    for mask in range(1, 15):
        _, curves = terrain_tiles.region_uv(mask, terrain_tiles.rng_for("grass-beach", mask))
        for curve in curves:
            for end in (curve[1], curve[-2]):  # first and last points inside the bleed
                assert min(abs(end[0] - 0.5) + abs(end[1]), abs(end[0] - 1) + abs(end[1] - 0.5),
                           abs(end[0] - 0.5) + abs(end[1] - 1), abs(end[0]) + abs(end[1] - 0.5)) < 1e-9


def test_generation_is_deterministic() -> None:
    assert terrain_tiles.sources() == terrain_tiles.sources()


@needs_rsvg
@pytest.mark.scenario("Neighbouring transition tiles join without a seam")
def test_neighbouring_tiles_join_without_a_seam(tmp_path: Path) -> None:
    sources = terrain_tiles.sources()
    names = ["terrain-grass-beach-t3", "terrain-grass-beach-t7"]
    svg_sprites.render_sources({name: sources[name] for name in names}, tmp_path, scales=(1,))
    west = Image.open(tmp_path / f"{names[0]}.png").convert("RGBA")
    east = Image.open(tmp_path / f"{names[1]}.png").convert("RGBA")
    # The mask-7 tile is one column east (+col) of the mask-3 tile: offset (32, 16) on the lattice.
    canvas = Image.new("RGBA", (96, 48), (0, 0, 0, 0))
    canvas.alpha_composite(west, (0, 0))
    canvas.alpha_composite(east, (32, 16))
    # Shared edge runs from (64, 16) to (32, 32) in canvas coordinates.
    gaps, jumps = 0, 0
    for step in range(2, 31):
        x, y = 64 - step, 16 + step / 2
        if canvas.getpixel((x, int(y)))[3] < 255:
            gaps += 1
        inside_west = west.getpixel((x - 1, int(y) - 1))
        inside_east = east.getpixel((x + 1 - 32, int(y) + 1 - 16))
        if sum(abs(a - b) for a, b in zip(inside_west[:3], inside_east[:3])) > 120:
            jumps += 1
    assert gaps == 0
    assert jumps <= 3  # only where the boundary itself crosses the edge
