"""Tree clumps for forest tiles (change `terrain-v2`, design D5)."""

from __future__ import annotations

import numpy as np
import pytest

from art import flora, terrain_objects


@pytest.mark.scenario("Tree clumps are repeatable")
def test_tree_clumps_are_repeatable() -> None:
    first = flora.render(flora.clump("sparse", 1, "spring"), "spring", scale=1)
    second = flora.render(flora.clump("sparse", 1, "spring"), "spring", scale=1)
    assert np.array_equal(first, second)


@pytest.mark.scenario("Seasons keep the same trees")
def test_seasons_keep_the_same_trees() -> None:
    """Trunks stand where they stood in spring, whatever the season does to the crowns."""

    def trunk_bases(season: str) -> set[tuple[float, float]]:
        spheres = flora.clump("dense", 2, season)
        return {(round(c[0], 6), round(c[2], 6)) for c, r, leafy in zip(spheres.centre, spheres.radius, spheres.leafy)
                if not leafy and c[1] < 0.01}

    spring = trunk_bases("spring")
    assert spring and spring == trunk_bases("autumn") == trunk_bases("winter")


def test_denser_clumps_hold_more_trees() -> None:
    def trees(density: str) -> int:
        spheres = flora.clump(density, 0, "spring")
        return sum(1 for c, leafy in zip(spheres.centre, spheres.leafy) if not leafy and c[1] < 0.01)

    assert 1 <= trees("sparse") < trees("medium") < trees("dense")


def test_every_object_name_parses_back() -> None:
    for name in terrain_objects.names():
        kind, density, season, variant = terrain_objects.parse(name)
        assert density in (terrain_objects.TREES if kind == "forest" else terrain_objects.ROCKS)
        assert season in ("spring", "autumn", "winter") and 0 <= variant < terrain_objects.VARIANTS
    assert len(terrain_objects.names()) == 3 * 3 * 4 + 4 * 2 * 4
