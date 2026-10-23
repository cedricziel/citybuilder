"""The app icon (issue #84): the citizen's gable house from IsoKit, close up on a grass plot under an
afternoon sky, with smoke from its chimney. Three layers, so tvOS can stack them for parallax:

- back: the sky and two hazy ridges, opaque
- middle: the grass plot, lit with the game's meadow texture
- front: the house and its smoke

`make app-icon` renders the house at 8x with `isokit render --only` and runs this module, which writes
the iOS marketing icon (no alpha channel), the macOS icon sizes and the tvOS brand assets. The asset
catalogs' Contents.json files name these PNGs and stay as they are.

    python -m art.app_icon --house <building-house-tier2@8x.png> --repo <repo root>
"""

from __future__ import annotations

import argparse
import re
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from art import ground

N = 1024  # master size
SS = 4  # supersampling for drawn shapes
HOUSE = "building-house-tier2"
FOOTPRINT_TILES = 2
PLOT = (512, 952, 470)  # the plot's bottom vertex x, y and its half width
HOUSE_WIDTH = 760  # footprint width on the master, in pixels
PLOT_TILES = 2 * PLOT[2] / (HOUSE_WIDTH / FOOTPRINT_TILES)  # 4 m tiles across the plot


@dataclass
class Layers:
    back: Image.Image
    middle: Image.Image
    front: Image.Image

    def flat(self) -> Image.Image:
        out = self.back.copy()
        out.alpha_composite(self.middle)
        out.alpha_composite(self.front)
        return out


def gradient(size: tuple[int, int], top, bottom) -> Image.Image:
    w, h = size
    t = np.linspace(0, 1, h)[:, None, None]
    rgb = np.array(top, float) + (np.array(bottom, float) - np.array(top, float)) * t
    return Image.fromarray(np.repeat(rgb, w, axis=1).astype(np.uint8), "RGB").convert("RGBA")


def polygons(size: tuple[int, int], shapes) -> Image.Image:
    """Antialiased polygons, each (points, rgba)."""
    w, h = size
    big = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(big)
    for points, colour in shapes:
        draw.polygon([(x * SS, y * SS) for x, y in points], fill=colour)
    return big.resize((w, h), Image.LANCZOS)


def sky(size: tuple[int, int]) -> Image.Image:
    """The back layer: warm afternoon sky and two soft ridges, hazy with distance. Ridge heights are
    fractions of the height, so a wide tvOS canvas keeps the same horizon."""
    w, h = size
    back = gradient(size, (126, 178, 214), (246, 214, 160))
    def ridge(ys):
        step = w / (len(ys) - 1)
        return [(i * step, y * h / N) for i, y in enumerate(ys)] + [(w, h), (0, h)]
    hills = polygons(size, [
        (ridge([560, 520, 548, 506, 534, 512]), (158, 178, 150, 255)),
        (ridge([610, 584, 606, 578, 598]), (130, 158, 104, 255)),
    ])
    back.alpha_composite(hills.filter(ImageFilter.GaussianBlur(2)))
    return back


def meadow(size: tuple[int, int], cx: float, by: float, half: float, tiles: float) -> Image.Image:
    """The game's lit meadow texture laid on the plot's top face, `tiles` tiles from corner to corner."""
    texture = Image.fromarray((ground.texture("grass").transpose(1, 0, 2) * 255 + 0.5).astype(np.uint8), "RGB")
    repeats = int(np.ceil(tiles)) + 1
    side = ground.SIZE
    sheet = Image.new("RGB", (side * repeats, side * repeats))
    for i in range(repeats):
        for j in range(repeats):
            sheet.paste(texture, (i * side, j * side))
    # Screen (x, y) to plot (u, v) in 0..1: u runs up the right edge, v up the left.
    k = tiles * side / half
    affine = (k / 2, -k, k * (by - cx / 2), -k / 2, -k, k * (by + cx / 2))
    return sheet.transform(size, Image.AFFINE, affine, resample=Image.BILINEAR).convert("RGBA")


def plot(size: tuple[int, int]) -> Image.Image:
    """The middle layer: a grass diamond a little wider than the house's plot, with earth sides."""
    cx, by, half = PLOT
    top = [(cx - half, by - half / 2), (cx, by - half), (cx + half, by - half / 2), (cx, by)]
    layer = polygons(size, [
        ([(cx - half, by - half / 2), (cx, by), (cx, by + 26), (cx - half, by - half / 2 + 26)], (84, 112, 56, 255)),
        ([(cx + half, by - half / 2), (cx, by), (cx, by + 26), (cx + half, by - half / 2 + 26)], (70, 96, 46, 255)),
    ])
    mask = polygons(size, [(top, (255, 255, 255, 255))]).getchannel("A")
    grass = meadow(size, cx, by, half, PLOT_TILES)
    grass.putalpha(mask)
    layer.alpha_composite(grass)
    return layer


def chimney_anchor(repo: Path) -> tuple[float, float]:
    """The house's chimney top as fractions of its sprite, from the game's own table."""
    source = (repo / "Packages/CityRender2D/Sources/CityRender2D/ChimneySmoke.swift").read_text()
    match = re.search(rf'"{HOUSE}": \(([\d.]+), ([\d.]+)\)', source)
    if not match:
        raise SystemExit(f"app_icon: no chimney anchor for {HOUSE} in ChimneySmoke.swift")
    return float(match[1]), float(match[2])


def smoke(canvas: Image.Image, x: float, y: float, scale: float) -> None:
    """A few soft puffs rising from the chimney top."""
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    for dx, dy, r, a in [(4, -18, 13, 150), (14, -44, 18, 120), (6, -78, 24, 90), (22, -116, 30, 60)]:
        px, py, pr = x + dx * scale, y + dy * scale, r * scale
        draw.ellipse([px - pr, py - pr, px + pr, py + pr], fill=(246, 242, 236, a))
    canvas.alpha_composite(layer.filter(ImageFilter.GaussianBlur(4 * scale)))


def house_layer(house: Image.Image, anchor: tuple[float, float]) -> Image.Image:
    """The front layer. The render's cell has its footprint's bottom vertex at the bottom centre and is
    64 points wide per footprint tile at @1x, so the footprint is scaled to `HOUSE_WIDTH`."""
    front = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    scale = HOUSE_WIDTH / (64 * FOOTPRINT_TILES * 8)
    scaled = house.resize((round(house.width * scale), round(house.height * scale)), Image.LANCZOS)
    cx, by, _ = PLOT
    left, top = round(cx - scaled.width / 2), round(by - 50 - scaled.height)
    front.alpha_composite(scaled, (left, top))
    smoke(front, left + anchor[0] * scaled.width, top + anchor[1] * scaled.height - 6, 1.6)
    return front


def compose(house: Image.Image, anchor: tuple[float, float]) -> Layers:
    return Layers(sky((N, N)), plot((N, N)), house_layer(house, anchor))


# --- Outputs ---------------------------------------------------------------------------------------


def mac_icon(flat: Image.Image) -> Image.Image:
    """The art in an 824/1024 rounded rect with a soft drop shadow, as macOS icons are drawn."""
    sheet = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    inner, offset, radius = 824, 100, 185
    shadow = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [offset, offset + 12, offset + inner, offset + inner + 12], radius=radius, fill=(0, 0, 0, 110)
    )
    sheet.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(14)))
    mask = Image.new("L", (inner * SS, inner * SS), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, inner * SS - 1, inner * SS - 1], radius=radius * SS, fill=255)
    tile = flat.resize((inner, inner), Image.LANCZOS)
    tile.putalpha(mask.resize((inner, inner), Image.LANCZOS))
    sheet.alpha_composite(tile, (offset, offset))
    return sheet


def tv_layer(art: Image.Image, width: int, height: int, *, back: bool) -> Image.Image:
    """One tvOS layer at `width` x `height`. The back layer is the sky redrawn at that size; the plot and
    the house stand bottom-centred, a little taller than the canvas so the plot's tip bleeds off."""
    if back:
        return sky((width, height))
    fit = art.resize((round(height * 1.12), round(height * 1.12)), Image.LANCZOS)
    layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    layer.alpha_composite(fit, ((width - fit.width) // 2, height - fit.height + round(height * 0.06)))
    return layer


def top_shelf(layers: Layers, width: int, height: int) -> Image.Image:
    out = sky((width, height))
    scene = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    scene.alpha_composite(layers.middle)
    scene.alpha_composite(layers.front)
    fit = scene.resize((round(height * 1.12), round(height * 1.12)), Image.LANCZOS)
    out.alpha_composite(fit, ((width - fit.width) // 2, height - fit.height + round(height * 0.06)))
    return out


def save(image: Image.Image, path: Path, *, opaque: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    (image.convert("RGB") if opaque else image).save(path, optimize=True)
    print(f"  wrote {path}")


def write(layers: Layers, repo: Path) -> None:
    flat = layers.flat()
    save(flat, repo / "Apps/CitybuilderiOS/Assets.xcassets/AppIcon.appiconset/icon-1024.png", opaque=True)

    mac = mac_icon(flat)
    for size in (16, 32, 64, 128, 256, 512, 1024):
        save(mac.resize((size, size), Image.LANCZOS), repo / f"Apps/CitybuilderMac/Assets.xcassets/AppIcon.appiconset/icon-{size}.png")

    brand = repo / "Apps/CitybuilderTV/Assets.xcassets/App Icon & Top Shelf Image.brandassets"
    for stack, (width, height), scales in (("App Icon", (400, 240), (1, 2)), ("App Store", (1280, 768), (1,))):
        folder = brand / ("App Icon.imagestack" if stack == "App Icon" else "App Icon - App Store.imagestack")
        for name, art in (("Back", None), ("Middle", layers.middle), ("Front", layers.front)):
            for scale in scales:
                image = tv_layer(art, width * scale, height * scale, back=art is None)
                file = folder / f"{name}.imagestacklayer/Content.imageset/{name.lower()}-{width}x{height}@{scale}x.png"
                save(image, file, opaque=art is None)
    for name, width in (("Top Shelf Image", 1920), ("Top Shelf Image Wide", 2320)):
        for scale in (1, 2):
            save(top_shelf(layers, width * scale, 720 * scale), brand / f"{name}.imageset/top-shelf-{width}x720@{scale}x.png", opaque=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--house", type=Path, required=True, help=f"{HOUSE} rendered at 8x")
    parser.add_argument("--repo", type=Path, required=True)
    args = parser.parse_args()
    house = Image.open(args.house).convert("RGBA")
    write(compose(house, chimney_anchor(args.repo)), args.repo)


if __name__ == "__main__":
    main()
