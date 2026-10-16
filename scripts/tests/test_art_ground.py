"""Lit ground textures repeat once per tile (capability `iso-art-kit`, design D6)."""

from __future__ import annotations

import numpy as np
import pytest

from art import ground


TEXTURES = ["grass", "grass-autumn", "grass-winter-1", "beach", "water-2",
            "forest-autumn", "forest-winter", "mountain", "mountain-v2"]


@pytest.mark.parametrize("name", TEXTURES)
def test_textures_wrap_without_a_seam(name: str) -> None:
    """Across the wrap the colour changes no more than between any two neighbouring texels."""
    texels = ground.texture(name)
    inner = np.abs(np.diff(texels, axis=0)).max(axis=2)
    wrap = np.abs(texels[0] - texels[-1]).max(axis=1)
    assert wrap.max() <= inner.max()
    assert wrap.mean() <= 3 * inner.mean()


def test_water_frames_loop() -> None:
    """Frame 4 would be frame 0 again, so the four-frame swell loops without a jump."""
    assert np.allclose(ground.shade(ground.water(4)), ground.shade(ground.water(0)), atol=0.08)


def test_seasons_differ_and_grass_stays_green() -> None:
    spring, autumn, winter = (ground.texture(n).mean(axis=(0, 1)) for n in ("grass", "grass-autumn", "grass-winter"))
    assert spring[1] > spring[0] and spring[1] > spring[2]  # green dominates
    assert autumn[0] / autumn[1] > spring[0] / spring[1]  # warmer
    assert winter.mean() > spring.mean() + 0.15  # snow and frost


def test_unknown_texture_is_rejected() -> None:
    with pytest.raises(ValueError):
        ground.texture("lava")


def test_winter_twigs_stay_off_the_conifers() -> None:
    """Only conifers rise above the floor in winter; the twig haze must never paint over them."""
    surface = ground.forest("winter")
    raised = surface.height > ground.FLOOR_HEIGHT + 1e-6
    assert raised.any()
    red, green = surface.albedo[..., 0][raised], surface.albedo[..., 1][raised]
    assert (red <= green + 0.02).all()


@pytest.mark.scenario("Variants share their edges")
def test_grass_variants_share_their_edges() -> None:
    """A variant differs only inside a window that vanishes on the tile edges, so any two join."""
    base = ground.texture("grass")
    for variant in range(1, ground.GRASS_VARIANTS):
        other = ground.texture(f"grass-v{variant}")
        assert np.abs(other - base).max() > 0.03  # it is a different tile
        for edge in (other[0] - base[0], other[-1] - base[-1], other[:, 0] - base[:, 0], other[:, -1] - base[:, -1]):
            assert np.abs(edge).max() < 1 / 255


def test_noise_seeds_use_the_whole_name() -> None:
    """Names that share their first eight characters still draw different noise: the grass sways."""
    assert not np.allclose(ground.noise("grass-blades-0", 0.035), ground.noise("grass-blades-1", 0.035))


@pytest.mark.parametrize("base,frames", [("grass", 2), ("grass-autumn", 2), ("grass-winter-v2", 2), ("beach", 2), ("water", 4)])
def test_animated_ground_keeps_its_edges_in_every_frame(base: str, frames: int) -> None:
    """Frames differ inside the tile only, so out-of-phase neighbours and the static shore tiles
    (baked from frame 0) always meet the same edge."""
    still = ground.texture(f"{base}-0")
    for frame in range(1, frames):
        moving = ground.texture(f"{base}-{frame}")
        assert np.abs(moving - still).max() > 0.01  # it does animate
        for edge in (moving[0] - still[0], moving[-1] - still[-1], moving[:, 0] - still[:, 0], moving[:, -1] - still[:, -1]):
            assert np.abs(edge).max() < 2 / 255
