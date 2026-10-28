"""Goods icons as hand-authored SVG (capability `iso-art-kit`, issue #195).

Each good is drawn as the object itself on a 24-unit grid: natural colours in three tones (main,
dark, light) plus up to two accents, lit from the upper left like the world, inside a dark warm
outline that keeps the silhouette readable on light and dark HUDs. The outline is an underlay: every
filled shape is drawn first in the outline colour with a wide stroke, then every shape in its colour
on top.

A shape is (tag, attributes, role, kind): `role` names a colour in the good's palette and `kind` is
"fill" or "stroke".
"""

from __future__ import annotations

SIZE = 24  # points at @1x
OUTLINE = "#2b1e15"
OUTLINE_WIDTH = 2.2  # the underlay's stroke, so the outline shows 1.1 units outside each shape

Shape = tuple[str, dict[str, object], str, str]


def shape(tag: str, role: str, kind: str = "fill", **attrs: object) -> Shape:
    return tag, {key.replace("_", "-"): value for key, value in attrs.items()}, role, kind


def log(x: float, y: float, w: float, h: float) -> list[Shape]:
    """A log on its side, its cut end to the right."""
    r = h / 2
    return [
        shape("rect", "main", x=x, y=y, width=w, height=h, rx=r),
        shape("rect", "dark", x=x + 2, y=y + h - 2.2, width=w - 4, height=1.2, rx=0.6),
        shape("ellipse", "light", cx=x + w - r, cy=y + r, rx=round(r * 0.8, 2), ry=r),
        shape("ellipse", "accent", "stroke", cx=x + w - r, cy=y + r, rx=round(r * 0.4, 2), ry=round(r * 0.5, 2), stroke_width=0.8),
    ]


def coffee_bean(x: float, y: float, angle: float) -> list[Shape]:
    turn = f"rotate({angle} {x} {y})"
    return [
        shape("ellipse", "main", cx=x, cy=y, rx=4.2, ry=5.6, transform=turn),
        shape("path", "dark", "stroke", d=f"M{x} {y - 4.4}c-1.6 2 1.6 6.8 0 8.8", stroke_width=1.1, transform=turn),
        shape("ellipse", "light", cx=x - 1.8, cy=y - 2, rx=0.9, ry=1.6, transform=turn),
    ]


GRAPES = [(7.5, 8.5), (12, 8), (16.5, 8.5), (9.8, 12.5), (14.2, 12.5), (12, 16.5), (7.8, 12.8), (16.2, 12.6), (12, 20.3)]
CHERRIES = [(7, 12, 3.4), (12.5, 14, 3.6), (8, 18.5, 3.3), (15.5, 19.5, 3)]
FLEECE = [(7, 11, 4.2), (12, 9, 4.6), (17, 11, 4.2), (5.5, 15.5, 3.8), (11, 15, 4.6), (16.5, 15.5, 4.2), (9, 19, 3.6), (14.5, 19, 3.6)]

GLYPHS: dict[str, list[Shape]] = {
    "wood": log(2.5, 12.5, 17, 7.5) + log(5, 5, 16.5, 7.5),
    "planks": [
        shape("rect", "dark", x=4, y=16, width=17, height=4.5, rx=0.8),
        shape("rect", "main", x=3, y=11, width=17, height=4.5, rx=0.8),
        shape("rect", "light", x=4.5, y=6, width=17, height=4.5, rx=0.8),
        shape("path", "accent", "stroke", d="M6 8.2h8M5 13.2h10M7 18.2h9", stroke_width=0.7),
    ],
    "food": [
        shape("path", "dark", d="M3 12h18l-2.2 8.5a1.5 1.5 0 0 1-1.5 1.1H6.7a1.5 1.5 0 0 1-1.5-1.1z"),
        shape("circle", "accent", cx=9, cy=10, r=4.2),
        shape("path", "accent2", d="M9 6.2c.6-1.8 2-2.6 3.4-2.4-.4 1.5-1.7 2.4-3.4 2.4z"),
        shape("ellipse", "light", cx=15.5, cy=10.5, rx=4.6, ry=3.2),
        shape("path", "main", "stroke", d="M4.5 15h15M5.3 18h13.4", stroke_width=0.8),
    ],
    "bread": [
        shape("path", "main", d="M2.5 15.5c0-5 4.3-8.5 9.5-8.5s9.5 3.5 9.5 8.5c0 2-1.5 3.5-3.5 3.5h-12c-2 0-3.5-1.5-3.5-3.5z"),
        shape("path", "dark", d="M3 16.5c.6 1.5 1.8 2.5 3 2.5h12c1.2 0 2.4-1 3-2.5z"),
        shape("path", "light", "stroke", d="M8 9.5l-1.5 3M12 8.6l-1.2 3.4M16 9.3l-1 3.2", stroke_width=1.2, stroke_linecap="round"),
    ],
    "grain": [
        shape("path", "dark", "stroke", d="M12 22V9M12 22l-4-11M12 22l4-11", stroke_width=1.2, stroke_linecap="round"),
        shape("ellipse", "main", cx=12, cy=6, rx=2.2, ry=4.4),
        shape("ellipse", "main", cx=7.4, cy=8, rx=2, ry=4, transform="rotate(-20 7.4 8)"),
        shape("ellipse", "main", cx=16.6, cy=8, rx=2, ry=4, transform="rotate(20 16.6 8)"),
        shape("ellipse", "light", cx=11.4, cy=5, rx=0.8, ry=2.2),
        shape("rect", "accent", x=8.6, y=15, width=6.8, height=2.4, rx=1),
    ],
    "flour": [
        shape("path", "main", d="M6 7.5c-1.8 3-2.8 6.5-2.8 9.5 0 3 2.3 4.5 8.8 4.5s8.8-1.5 8.8-4.5c0-3-1-6.5-2.8-9.5z"),
        shape("path", "dark", d="M18 7.5c1.8 3 2.8 6.5 2.8 9.5 0 3-2.3 4.5-8.8 4.5 3 0 5.2-1.5 5.6-4.5.3-3-.3-6.5-1.6-9.5z"),
        shape("path", "light", d="M7 7.5l-1.5-4h13l-1.5 4z"),
        shape("rect", "accent", x=6.2, y=6.6, width=11.6, height=1.8, rx=0.9),
        shape("ellipse", "accent2", cx=11, cy=15, rx=2.2, ry=3),
    ],
    "ore": [
        shape("path", "main", d="M2.5 19l3-8 5-4.5 6 1.5 5 6 .5 5z"),
        shape("path", "dark", d="M16.5 8l5 6 .5 5h-7z"),
        shape("path", "light", d="M5.5 11l5-4.5 2 3-5 3.5z"),
        shape("circle", "accent", cx=9, cy=15, r=1.4),
        shape("circle", "accent", cx=14.5, cy=12.5, r=1.1),
        shape("circle", "accent", cx=13, cy=17, r=1),
    ],
    "charcoal": [
        shape("path", "main", d="M2.5 20l2-6 5-2 3 3-1 5z"),
        shape("path", "dark", d="M10.5 20l1.5-6.5 5.5-2.5 4 4 .5 5z"),
        shape("path", "main", d="M7 12.5l2-6 5.5-1.5 3 4.5-3 3.5-5 .5z"),
        shape("path", "light", d="M9 6.5l5.5-1.5 1.2 1.8-6.4 1.6z"),
        shape("path", "accent", "stroke", d="M13.5 15.5l2-1M5 17l2.5-1", stroke_width=0.8),
    ],
    "iron": [
        shape("path", "dark", d="M3 20l2-5h14l2 5z"),
        shape("path", "main", d="M5 15l1.6-3.5h10.8L19 15z"),
        shape("path", "main", d="M6.5 11l2-5h7l2 5z"),
        shape("path", "light", d="M8.5 6h7l.6 1.4H7.9z"),
        shape("path", "light", d="M6.6 11.5h10.8l.4 1H6.2z"),
    ],
    "tools": [
        shape("path", "dark", "stroke", d="M5 20L16 9", stroke_width=2.4, stroke_linecap="round"),
        shape("path", "dark", "stroke", d="M19 20L8 9", stroke_width=2.4, stroke_linecap="round"),
        shape("path", "main", d="M12.5 7.5l3-3 5 5-3 3z"),
        shape("path", "light", d="M3 6.5C5 3.5 9 3 11.5 5.5l-2 2C8 6.2 6 6 3 6.5z"),
        shape("path", "light", d="M15.5 4.5l1-1 5 5-1 1z"),
    ],
    "hops": [
        shape("path", "accent2", "stroke", d="M12 2.5c0 3-2 4-4 6M12 2.5c0 3 2 4 4 6", stroke_width=1),
        shape("path", "main", d="M8 8c-3 0-4.5 3-4.5 6 0 3.5 2 6.5 4.5 7.5 2.5-1 4.5-4 4.5-7.5 0-3-1.5-6-4.5-6z"),
        shape("path", "main", d="M16 8c-3 0-4.5 3-4.5 6 0 3.5 2 6.5 4.5 7.5 2.5-1 4.5-4 4.5-7.5 0-3-1.5-6-4.5-6z"),
        shape("path", "dark", "stroke", d="M4.2 12.5h7.6M4 16h8M5.5 19h5M12.2 12.5h7.6M12 16h8M13.5 19h5", stroke_width=0.8),
        shape("path", "light", d="M15 9.5c1.5 0 2.5 1 3 2.5h-4.2c.2-1.3.6-2.5 1.2-2.5z"),
    ],
    "beer": [
        shape("path", "dark", "stroke", d="M17.5 10h2a2 2 0 0 1 2 2v3a2 2 0 0 1-2 2h-2", stroke_width=1.8),
        shape("rect", "main", x=4.5, y=8, width=13, height=13.5, rx=1.5),
        shape("rect", "dark", x=13.5, y=8, width=4, height=13.5, rx=1.2),
        shape("path", "light", d="M4 9c-1-2 .5-4.5 3-4.2C7.7 3 10 2.6 11.5 4c1.4-1.2 4-1 5 .6 2.2 0 3 2.4 1.8 4.4z"),
        shape("path", "accent", "stroke", d="M8 12v7M11 12v7", stroke_width=0.9, stroke_linecap="round"),
    ],
    "grapes": [
        shape("path", "accent2", d="M12 5.5c1.5-2.5 5-3.5 8-2-1.5 2.8-4.5 3.8-8 2z"),
        shape("path", "accent", "stroke", d="M12 6V2.5", stroke_width=1.2),
        *[shape("circle", "main", cx=x, cy=y, r=2.6) for x, y in GRAPES],
        *[shape("circle", "light", cx=round(x - 0.8, 2), cy=round(y - 0.9, 2), r=0.8) for x, y in GRAPES[:2] + GRAPES[3:4] + GRAPES[5:6]],
        shape("circle", "dark", cx=16.2, cy=12.6, r=2.6),
    ],
    "wine": [  # an amphora: wine is stored in amphorae
        shape("path", "main", d="M9 3.5h6v2c0 1 3.5 2.5 3.5 7 0 4-2.5 6.5-4 8l-1 1.5h-3L9.5 20.5c-1.5-1.5-4-4-4-8 0-4.5 3.5-6 3.5-7z"),
        shape("path", "dark", d="M15 5.5c0 1 3.5 2.5 3.5 7 0 4-2.5 6.5-4 8l-1 1.5h-1c1-1.5 3-4.5 3-9 0-4-.5-6-.5-7.5z"),
        shape("path", "dark", "stroke", d="M9 7c-2.5 0-3.5 1.5-3.5 3M15 7c2.5 0 3.5 1.5 3.5 3", stroke_width=1.2),
        shape("rect", "light", x=8.5, y=2.5, width=7, height=1.8, rx=0.6),
        shape("path", "accent", "stroke", d="M6.6 12h10.8", stroke_width=1.1),
    ],
    "tea-leaves": [
        shape("path", "dark", "stroke", d="M4 21c4-4 8-8 10-15", stroke_width=1.1, stroke_linecap="round"),
        shape("path", "main", d="M14 6c-4 0-7 3-7.5 8 4.5 0 7.5-3.5 7.5-8z"),
        shape("path", "light", d="M11 12c4.5-.5 9-2 10-7.5-5 0-9 3-10 7.5z"),
        shape("path", "main", d="M8 17c3.5 1.5 8 1 10-2.5-3.5-1.5-8-1-10 2.5z"),
        shape("path", "accent", "stroke", d="M7 13.5l6-6M12 11.5l8-6M9 16.8l8.5-2", stroke_width=0.6),
    ],
    "tea": [
        shape("path", "dark", "stroke", d="M18.5 11c2.5 0 3 2.5 1.5 4-1 1-2 1.3-2.5 1.3", stroke_width=1.6),
        shape("path", "dark", d="M5.5 13L1.5 9.5l1.2-.8L7 11z"),
        shape("ellipse", "main", cx=11.5, cy=15, rx=7.5, ry=6),
        shape("path", "dark", d="M18.5 14.5c0 3.3-3.3 6-7 6.4 3-1 4.8-3.5 4.8-6.4 0-2.8-1.6-5.2-4.2-6.2 3.6.3 6.4 2.9 6.4 6.2z"),
        shape("rect", "accent", x=4.1, y=14, width=14.8, height=2.2),
        shape("ellipse", "light", cx=11.5, cy=9.2, rx=4, ry=1.4),
        shape("circle", "light", cx=11.5, cy=7.2, r=1.4),
    ],
    "coffee-cherries": [
        shape("path", "accent", "stroke", d="M3 6c5 0 9 1 13 4", stroke_width=1.2, stroke_linecap="round"),
        shape("path", "accent2", d="M14 9c1-4 4.5-6 8-5.5-1 3.5-4 5.5-8 5.5z"),
        *[shape("circle", "main", cx=x, cy=y, r=r) for x, y, r in CHERRIES],
        shape("circle", "dark", cx=15.5, cy=19.5, r=3),
        *[shape("circle", "light", cx=x, cy=y, r=0.9) for x, y in [(5.9, 10.9), (11.3, 12.8), (7, 17.3)]],
    ],
    "coffee": coffee_bean(8, 9, -30) + coffee_bean(16, 10, 25) + coffee_bean(11.5, 17, 10),
    "wool": [  # a fleece tied round the middle
        *[shape("circle", "main", cx=x, cy=y, r=r) for x, y, r in FLEECE],
        *[shape("circle", "light", cx=x - 1.2, cy=y - 1.4, r=round(r * 0.45, 2)) for x, y, r in FLEECE[:3]],
        shape("path", "dark", "stroke", d="M4 13.5c5 2 11 2 16 0", stroke_width=1.3, stroke_linecap="round"),
        shape("circle", "dark", cx=19.5, cy=19.5, r=1.6),
    ],
    "cloth": [  # two folded bolts, madder on woad
        shape("rect", "accent2", x=3, y=13.5, width=18, height=6.5, rx=1.6),
        shape("rect", "main", x=4, y=6, width=17, height=7, rx=1.6),
        shape("path", "dark", d="M4 11h17v2H4z"),
        shape("path", "light", "stroke", d="M7 8.2h9", stroke_width=1, stroke_linecap="round"),
        shape("path", "accent", "stroke", d="M6 16.2h11", stroke_width=1, stroke_linecap="round"),
    ],
}

# main, dark, light, accent (defaults to dark), accent2 (defaults to main)
PALETTES: dict[str, tuple[str, str, str, str | None, str | None]] = {
    "wood": ("#8a5a32", "#5c3a1e", "#e0b178", "#a8743f", None),
    "planks": ("#c48f55", "#9c6b3a", "#ddb07a", "#8a5a30", None),
    "food": ("#e8d4a2", "#8f6436", "#e2b05e", "#c8402e", "#5d8a35"),
    "bread": ("#cf8a3e", "#9a5d26", "#f2cf8e", None, None),
    "grain": ("#e3bf55", "#a88a35", "#f6e29a", "#9a6a35", None),
    "flour": ("#efe6d2", "#c9bea6", "#d8ccb0", "#8f6a3e", "#e2c070"),
    "ore": ("#8d857c", "#5f5953", "#b3aca4", "#c4612e", None),
    "charcoal": ("#3b3836", "#252322", "#6a6f78", "#e07a3a", None),
    "iron": ("#8f98a3", "#5d6570", "#c8d0d8", None, None),
    "tools": ("#9aa3ad", "#8a5a32", "#c5ccd3", None, None),
    "hops": ("#8cbf5a", "#4f7d2e", "#c3e08e", None, "#5d8a35"),
    "beer": ("#e0a33a", "#a8701e", "#fbf3df", "#f2c86a", None),
    "grapes": ("#6c3c86", "#4a2660", "#b98ad0", "#7a5a30", "#5d8a35"),
    "wine": ("#c0663a", "#8c4224", "#e6a57a", "#f2d6b0", None),
    "tea-leaves": ("#4f8a3a", "#5c3a1e", "#7ab55a", "#d8ecc0", None),
    "tea": ("#f3efe6", "#c9c1b2", "#ffffff", "#3f7ab0", None),
    "coffee-cherries": ("#c8352b", "#8e2019", "#f08a7a", "#6a4a2a", "#4f8a3a"),
    "coffee": ("#6e4426", "#3d2412", "#a77a52", None, None),
    "wool": ("#ece4cf", "#9a7a50", "#ffffff", None, None),
    "cloth": ("#b5473a", "#7f2a22", "#e08a76", "#9cb4d8", "#3f5f8f"),
}


def colours(good: str) -> dict[str, str]:
    main, dark, light, accent, accent2 = PALETTES[good]
    return {"main": main, "dark": dark, "light": light, "accent": accent or dark, "accent2": accent2 or main}


def _element(tag: str, attrs: dict[str, object], colour: str, kind: str, extra: dict[str, object] | None = None) -> str:
    merged = {**attrs, **({"fill": colour} if kind == "fill" else {"stroke": colour, "fill": "none"}), **(extra or {})}
    return f"<{tag} " + " ".join(f'{key}="{value}"' for key, value in merged.items()) + "/>"


def svg(good: str) -> str:
    palette = colours(good)
    shapes = GLYPHS[good]
    underlay = []
    for tag, attrs, role, kind in shapes:
        if kind == "fill":
            underlay.append(_element(tag, attrs, OUTLINE, "fill", {"stroke": OUTLINE, "stroke-width": OUTLINE_WIDTH, "stroke-linejoin": "round"}))
        elif role != "light" and float(str(attrs.get("stroke-width", 1))) >= 1:
            # Strokes that form the silhouette (handles, stems) are outlined too; fine detail lines are not.
            width = round(float(str(attrs["stroke-width"])) + OUTLINE_WIDTH, 2)
            underlay.append(_element(tag, {**attrs, "stroke-width": width}, OUTLINE, "stroke"))
    body = [_element(tag, attrs, palette[role], kind) for tag, attrs, role, kind in shapes]
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" viewBox="0 0 {SIZE} {SIZE}">'
        + "".join(underlay + body)
        + "</svg>"
    )


def sources() -> dict[str, str]:
    """Every goods icon, `good-<good>`."""
    return {f"good-{good}": svg(good) for good in GLYPHS}
