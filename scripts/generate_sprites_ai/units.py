"""Procedural walkers and ships in the building register: palette roles,
`#1A1410` outline, light from the north-west."""

from __future__ import annotations

import math

from PIL import Image, ImageDraw

from .palette import (
    CREAM, DARK_TIMBER, GLINT, MEDIUM_LOAM, OUTLINE, PALE_SAND, PINE, SUN_TERRACOTTA,
    TERRACOTTA, TIMBER, WHEAT, Rgb,
)

_WALKER_KEY: dict[str, Rgb] = {
    "O": OUTLINE, "H": DARK_TIMBER, "S": WHEAT, "T": SUN_TERRACOTTA, "t": TERRACOTTA,
    "B": DARK_TIMBER, "L": MEDIUM_LOAM, "K": PALE_SAND, "k": PINE,
}

# 8×12 figures carrying a sack. Front views face south (se/sw), back
# views face north (ne/nw); west-facing frames are mirrored.
_FRONT = [
    [
        "..HHH...",
        ".HSSSH..",
        "..SSS...",
        ".TTTTTKK",
        "TTTTTtKk",
        "STTTTtkk",
        ".TBBBt..",
        ".TTTTt..",
        ".LL.LL..",
        ".L...L..",
        ".L...L..",
        "OO...OO.",
    ],
    [
        "..HHH...",
        ".HSSSH..",
        "..SSS...",
        ".TTTTTKK",
        "TTTTTtKk",
        "STTTTtkk",
        ".TBBBt..",
        ".TTTTt..",
        "..LLL...",
        "..LL....",
        "..LLL...",
        "..OOO...",
    ],
]
_BACK = [
    [
        "..HHH...",
        ".HHHHH..",
        "..HHH...",
        "KKTTTTT.",
        "kKTTTTtT",
        "kkTTTTtS",
        "..TBBBt.",
        "..TTTTt.",
        "..LL.LL.",
        "..L...L.",
        "..L...L.",
        ".OO...OO",
    ],
    [
        "..HHH...",
        ".HHHHH..",
        "..HHH...",
        "KKTTTTT.",
        "kKTTTTtT",
        "kkTTTTtS",
        "..TBBBt.",
        "..TTTTt.",
        "...LLL..",
        "....LL..",
        "...LLL..",
        "...OOO..",
    ],
]


def walker(facing: str, frame: int) -> Image.Image:
    rows = (_BACK if facing.startswith("n") else _FRONT)[frame]
    img = Image.new("RGBA", (8, 12), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != ".":
                img.putpixel((x, y), (*_WALKER_KEY[ch], 255))
    if facing.endswith("w"):
        img = img.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    return img


# World-space headings (x = +u east, y = +v south).
_HEADINGS = {
    "n": (0.0, -1.0), "ne": (1.0, -1.0), "e": (1.0, 0.0), "se": (1.0, 1.0),
    "s": (0.0, 1.0), "sw": (-1.0, 1.0), "w": (-1.0, 0.0), "nw": (-1.0, -1.0),
}


def ship(facing: str, frame: int) -> Image.Image:
    """32×16 cog: dark hull with a pine deck, a mast and a square sail;
    frames alternate the sail's billow and the bow foam."""
    img = Image.new("RGBA", (32, 16), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    dx, dy = _HEADINGS[facing]
    norm = math.hypot(dx, dy)
    dx, dy = dx / norm, dy / norm
    px, py = -dy, dx
    cx, cy = 16.0, 12.0
    k = 22.0

    def proj(x: float, y: float, z: float = 0.0) -> tuple[int, int]:
        return round(cx + (x - y) * k / 2), round(cy + (x + y) * k / 4 - z)

    length, beam = 0.5, 0.17
    outline_pts = [(length, 0.0), (0.2, beam), (-length, beam * 0.8), (-length, -beam * 0.8), (0.2, -beam)]
    hull = [(dx * a + px * b, dy * a + py * b) for a, b in outline_pts]
    draw.polygon([proj(x, y) for x, y in hull], fill=(*DARK_TIMBER, 255), outline=(*OUTLINE, 255))
    draw.polygon([proj(x * 0.8, y * 0.8, 2) for x, y in hull], fill=(*PINE, 255))
    mx, my = proj(0.0, 0.0, 2)
    draw.line([(mx, my), (mx, my - 9)], fill=(*TIMBER, 255))
    sail_half = 3
    sx = round(px * 4) if abs(px) > 0.3 else 0
    sail = [(mx - sail_half, my - 9), (mx + sail_half, my - 9), (mx + sail_half + sx // 2, my - 4), (mx - sail_half + sx // 2, my - 4)]
    draw.polygon(sail, fill=(*PALE_SAND, 255), outline=(*OUTLINE, 255))
    if frame == 1:
        draw.line([(mx, my - 8), (mx + sx // 2, my - 5)], fill=(*CREAM, 255))
    bx, by = proj(dx * (length + 0.06), dy * (length + 0.06))
    foam = [(bx, by), (bx + 1, by)] if frame == 0 else [(bx, by + 1), (bx - 1, by)]
    for x, y in foam:
        if 0 <= x < 32 and 0 <= y < 16:
            img.putpixel((x, y), (*GLINT, 255))
    return img
