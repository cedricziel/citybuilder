"""Road tiles join their neighbours (capability `iso-art-kit`)."""

from __future__ import annotations

import random
import re
from pathlib import Path

import numpy as np
import pytest

from art import roads


def mask_at(paved: set[tuple[int, int]], x: int, y: int) -> int:
    """Mirror of `RoadLinks.links` in CityRender2D."""
    mask = 0
    for bit, (dx, dy) in roads.ARMS:
        if (x + dx, y + dy) in paved:
            mask |= bit
    arms = dict(roads.ARMS)
    for bit, a, b in roads.CORNERS:
        (adx, ady), (bdx, bdy) = arms[a], arms[b]
        if mask & a and mask & b and (x + adx + bdx, y + ady + bdy) in paved:
            mask |= bit
    return mask


def test_every_mask_a_road_can_have_is_drawn() -> None:
    assert len(roads.masks()) == 47  # RoadLinks.allMasks in CityRender2D has the same count
    names = set(roads.sources())
    for mask in roads.masks():
        assert roads.name(mask, "earth") in names and roads.name(mask, "plaza") in names


@pytest.mark.scenario("Road tiles join without a step")
def test_road_tiles_join_without_a_step() -> None:
    """On random road networks, road cover matches across every shared edge."""
    rng = random.Random(4)
    edge = np.linspace(0.01, 0.99, 64)
    for _ in range(30):
        paved = {(x, y) for x in range(6) for y in range(6) if rng.random() < 0.55}
        masks = {tile: mask_at(paved, *tile) for tile in paved}
        assert set(masks.values()) <= set(roads.masks())
        for (x, y), mask in masks.items():
            for neighbour, here, there in (((x + 1, y), (np.ones_like(edge), edge), (np.zeros_like(edge), edge)),
                                           ((x, y + 1), (edge, np.ones_like(edge)), (edge, np.zeros_like(edge)))):
                if neighbour not in masks:
                    continue
                mine = roads.coverage(mask, *here)
                theirs = roads.coverage(masks[neighbour], *there)
                assert np.abs(mine - theirs).max() < 0.05, (x, y, mask, neighbour, masks[neighbour])


def test_masks_match_the_brief_the_renderer_reads() -> None:
    """The road brief lists one sprite per mask; CityRender2D's RoadLinksTests checks the same list
    against RoadLinks.allMasks, so the brief ties the two mask sets together."""
    brief = (Path(__file__).resolve().parents[2] / "Resources/Sprites.style/catalog/building-road.md").read_text()
    earth = {int(m) for m in re.findall(r"`building-road-c(\d+)`", brief)}
    plaza = {int(m) for m in re.findall(r"`building-road-plaza-c(\d+)`", brief)}
    assert earth == plaza == set(roads.masks())


@pytest.mark.parametrize("surface", roads.SURFACES)
def test_surfaces_repeat_once_per_tile(surface: str) -> None:
    """Across the wrap the colour changes no more than between neighbouring texels, so road tiles
    join without a seam in their texture."""
    texels = roads.surface(surface)
    for axis in (0, 1):
        inner = np.abs(np.diff(texels, axis=axis)).max()
        wrap = np.abs(np.take(texels, 0, axis=axis) - np.take(texels, -1, axis=axis)).max()
        assert wrap <= inner


def test_an_unconnected_road_is_transparent_at_its_edges() -> None:
    """With no paved neighbour the road stays a patch in the middle, so grass meets grass."""
    edge = np.linspace(0, 1, 32)
    assert roads.coverage(0, np.zeros_like(edge), edge).max() < 0.01
