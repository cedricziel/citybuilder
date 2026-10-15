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


N, E, S, W = 1, 2, 4, 8
# Neighbour one column east (+col) sits at (32, 16) and shares our E-S edge with its N-W edge;
# one row south (+row) sits at (-32, 16) and shares our S-W edge with its E-N edge.
NEIGHBOURS = {
    (32, 16): ((E, N), (S, W)),
    (-32, 16): ((W, N), (S, E)),
}


def seam_faults(west: Image.Image, east: Image.Image, offset: tuple[int, int]) -> tuple[int, int]:
    """Gaps (unpainted pixels) and colour jumps along the edge two placed tiles share."""
    dx, dy = offset
    canvas = Image.new("RGBA", (160, 48), (0, 0, 0, 0))
    canvas.alpha_composite(west, (32, 0))
    canvas.alpha_composite(east, (32 + dx, dy))
    sign = 1 if dx > 0 else -1
    gaps, jumps = 0, 0
    for step in range(2, 31):
        x, y = 64 + sign * (32 - step), 16 + step / 2  # canvas point on the shared edge
        if canvas.getpixel((int(x), int(y)))[3] < 255:
            gaps += 1
        inside_west = west.getpixel((int(x) - 32 - sign, int(y - 1)))
        inside_east = east.getpixel((int(x) - 32 - dx + sign, int(y - dy + 1)))
        if sum(abs(a - b) for a, b in zip(inside_west[:3], inside_east[:3])) > 120:
            jumps += 1
    return gaps, jumps


@needs_rsvg
@pytest.mark.scenario("Neighbouring transition tiles join without a seam")
def test_neighbouring_tiles_join_without_a_seam(tmp_path: Path) -> None:
    sources = terrain_tiles.sources()
    svg_sprites.render_sources(sources, tmp_path, scales=(1,))
    tiles = {name: Image.open(tmp_path / f"{name}.png").convert("RGBA") for name in sources}
    checked, faults = 0, []
    for pair in ("grass-beach", "beach-water"):
        for here in range(1, 15):
            for there in range(1, 15):
                for offset, corners in NEIGHBOURS.items():
                    if any(bool(here & mine) != bool(there & theirs) for mine, theirs in corners):
                        continue
                    gaps, jumps = seam_faults(tiles[f"terrain-{pair}-t{here}"], tiles[f"terrain-{pair}-t{there}"], offset)
                    checked += 1
                    # Colour may change along an edge only where the boundary crosses it (its two corners differ).
                    crossed = len({bool(here & mine) for mine, _ in corners}) == 2
                    if gaps or jumps > (6 if crossed else 0):
                        faults.append((pair, here, there, offset, gaps, jumps))
    assert checked == 200
    assert faults == []
