"""The app icon: three layers composed from the IsoKit house, written to every platform's asset catalog."""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

from art import app_icon

REPO = Path(__file__).resolve().parents[2]


def _house() -> Image.Image:
    """A stand-in for the 8x render: a 2x2 cell (1536 x 1152) with an opaque block over the footprint."""
    house = Image.new("RGBA", (1536, 1152), (0, 0, 0, 0))
    house.paste((180, 60, 40, 255), (400, 300, 1136, 1100))
    return house


def test_layers_stack_into_an_opaque_icon() -> None:
    layers = app_icon.compose(_house(), (0.5, 0.25))
    assert np.asarray(layers.back.getchannel("A")).min() == 255
    assert np.asarray(layers.flat().getchannel("A")).min() == 255
    # The plot and the house leave the sky's corners to the back layer.
    for layer in (layers.middle, layers.front):
        assert layer.getpixel((0, 0))[3] == 0


def test_the_plot_is_meadow() -> None:
    """The plot's top face carries the game's lit grass, so it is green and not one flat colour."""
    middle = np.asarray(app_icon.plot((app_icon.N, app_icon.N)).convert("RGB"), dtype=float)
    cx, by, half = app_icon.PLOT
    face = middle[round(by - half * 0.6) : round(by - half * 0.4), cx - 60 : cx + 60]
    r, g, b = face.reshape(-1, 3).mean(axis=0)
    assert g > r and g > b
    assert face.std() > 2


def test_the_chimney_anchor_comes_from_the_game() -> None:
    x, y = app_icon.chimney_anchor(REPO)
    assert 0 < x < 1 and 0 < y < 1


def test_every_icon_is_written(tmp_path: Path) -> None:
    app_icon.write(app_icon.compose(_house(), (0.5, 0.25)), tmp_path)
    ios = Image.open(tmp_path / "Apps/CitybuilderiOS/Assets.xcassets/AppIcon.appiconset/icon-1024.png")
    assert ios.size == (1024, 1024) and ios.mode == "RGB"  # App Store Connect rejects an alpha channel
    for size in (16, 32, 64, 128, 256, 512, 1024):
        mac = Image.open(tmp_path / f"Apps/CitybuilderMac/Assets.xcassets/AppIcon.appiconset/icon-{size}.png")
        assert mac.size == (size, size)
        assert mac.getpixel((0, 0))[3] == 0  # the rounded rect leaves its corners clear
    brand = tmp_path / "Apps/CitybuilderTV/Assets.xcassets/App Icon & Top Shelf Image.brandassets"
    for layer, mode in (("back", "RGB"), ("middle", "RGBA"), ("front", "RGBA")):
        name = layer.capitalize()
        small = Image.open(brand / f"App Icon.imagestack/{name}.imagestacklayer/Content.imageset/{layer}-400x240@2x.png")
        store = Image.open(brand / f"App Icon - App Store.imagestack/{name}.imagestacklayer/Content.imageset/{layer}-1280x768@1x.png")
        assert (small.size, small.mode) == ((800, 480), mode)  # only the back layer is opaque
        assert (store.size, store.mode) == ((1280, 768), mode)
    shelf = Image.open(brand / "Top Shelf Image Wide.imageset/top-shelf-2320x720@2x.png")
    assert (shelf.size, shelf.mode) == ((4640, 1440), "RGB")
