"""Rock outcrops: weathered at a region's rim, crags inside (change `terrain-v2`, design D5)."""

from __future__ import annotations

import numpy as np
import pytest

from art import rocks


def height(blocks: list[rocks.Block]) -> float:
    """The outcrop's top: the highest point any block reaches, from its upward plane offsets."""
    tops = []
    for block in blocks:
        up = np.argmax(block.normals[:, 1])
        tops.append(block.offsets[up] / block.normals[up, 1])
    return max(tops)


@pytest.mark.scenario("Outcrops are repeatable")
def test_outcrops_are_repeatable() -> None:
    first = rocks.sprite("peak", 2, "spring", scale=1)
    second = rocks.sprite("peak", 2, "spring", scale=1)
    assert np.array_equal(first, second)


@pytest.mark.scenario("Crags rise above the rim")
def test_crags_rise_above_the_rim() -> None:
    """Every peak variant stands taller than every medium one, so a region gets a summit."""
    peaks = [height(rocks.outcrop("peak", v)) for v in range(4)]
    rims = [height(rocks.outcrop("medium", v)) for v in range(4)]
    assert min(peaks) > max(rims)


def test_winter_keeps_the_same_stones() -> None:
    """Snow only changes the tops, so the silhouette is the same in every season."""
    spring = rocks.sprite("dense", 1, "spring", scale=1)[..., 3] > 0.5
    winter = rocks.sprite("dense", 1, "winter", scale=1)[..., 3] > 0.5
    assert np.array_equal(spring, winter)
