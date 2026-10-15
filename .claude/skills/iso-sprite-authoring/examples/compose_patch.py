"""Render the example sprite sources and lay them on a small iso patch.

usage: python3 -I compose.py <examples-dir> <out-dir>
Writes patch@1x.png, patch@1x-nearest3x.png (what the game shows today with
.nearest filtering at 3x), and patch@3x.png (sources rendered at 3x).
"""
import os
import subprocess
import sys

from PIL import Image

EX, OUT = sys.argv[1], sys.argv[2]
os.makedirs(OUT, exist_ok=True)
NAMES = ["house", "tile-grass", "tile-grass-sand", "tile-sand",
         "tile-sand-water", "tile-water", "walker"]
KIND = {1: "tile-grass-sand", 2: "tile-sand", 3: "tile-sand-water", 4: "tile-water"}


def render(name, z):
    path = f"{OUT}/{name}@{z}x.png"
    subprocess.run(["rsvg-convert", "-z", str(z), f"{EX}/{name}.svg", "-o", path], check=True)
    return Image.open(path).convert("RGBA")


def pt(c, r, ox=180, oy=80):
    return ox + 32 * (c - r), oy + 16 * (c + r)


HOUSE = sys.argv[3] if len(sys.argv) > 3 else None  # e.g. "house3d": use <OUT>/house3d@<z>x.png
TAG = f"-{HOUSE}" if HOUSE else ""


def compose(z):
    spr = {n: render(n, z) for n in NAMES}
    if HOUSE:
        spr["house"] = Image.open(f"{OUT}/{HOUSE}@{z}x.png").convert("RGBA")
    img = Image.new("RGBA", (420 * z, 270 * z), (24, 40, 52, 255))
    for s in range(-2, 9):  # back to front
        for c in range(0, 5):
            r = s - c
            if -2 <= r <= 4:
                x, y = pt(c, r)
                img.alpha_composite(spr[KIND.get(r, "tile-grass")], ((x - 32) * z, y * z))
    bx, by = pt(3, 0)  # bottom corner of the 2x2 footprint c1-2, r-2..-1
    img.alpha_composite(spr["house"], ((bx - 64) * z, (by - 112) * z))
    for c, r in [(2.5, 2.5), (3.6, 2.2)]:
        x, y = pt(c, r)
        img.alpha_composite(spr["walker"], (int((x - 5) * z), int((y - 15) * z)))
    return img


one = compose(1)
one.save(f"{OUT}/patch{TAG}@1x.png")
one.resize((one.width * 3, one.height * 3), Image.NEAREST).save(f"{OUT}/patch{TAG}@1x-nearest3x.png")
compose(3).save(f"{OUT}/patch{TAG}@3x.png")
print("ok")
