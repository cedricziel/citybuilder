"""Building status icons as hand-authored SVG (spec `rendering-2_5d`, change add-building-status-icons).

One icon floats over a building while something is wrong. Two families share a 28-unit grid and the
goods icons' dark warm outline:

- Pictograms: a white glyph on a red disc, crossed by a slash when something is missing
  (`status-no-road`).
- Goods: the existing goods icon on a cream disc, with a pip in the lower right. A red "!" means the
  good is short: a missing input or an unmet house need (`status-bread-short`). An amber pause means
  output is stuck or the building rests on stock (`status-planks-stuck`).

Design canvas: https://claude.ai/artifact/JMuRyVB1tHAFthEbFxdE2F (option A, "Disc").
"""

from __future__ import annotations

import re

from art import goods_icons

SIZE = 28  # points at @1x; the disc itself is 24
OUTLINE = goods_icons.OUTLINE
RED = "#c8402e"
AMBER = "#d9962b"
CREAM = "#f7eedb"
WHITE = "#ffffff"


def _glyphs(colour: str) -> dict[str, str]:
    """White pictograms on a 24-unit grid."""
    stroke = f'fill="none" stroke="{colour}" stroke-linecap="round" stroke-linejoin="round"'
    fill = f'fill="{colour}"'
    return {
        "no-road": f'<path {stroke} stroke-width="2.2" d="M7.5 20.5 10 3.5M16.5 20.5 14 3.5"/>'
        f'<path {stroke} stroke-width="1.6" d="M12 17.5v-2.5M12 11.5v-2M12 6.5v-1"/>',
        "no-route": f'<path {stroke} stroke-width="2.2" d="M3.5 11 12 4.5l8.5 6.5v9.5h-17z"/>'
        f'<path {stroke} stroke-width="1.8" d="M8.5 20.5v-5.5h7v5.5M8.5 17.5h7"/>',
        "no-trees": f'<circle {fill} cx="12" cy="9" r="6"/><path {stroke} stroke-width="2.2" d="M12 14v7"/>',
        "no-room-to-plant": f'<path {stroke} stroke-width="2.2" d="M12 20.5V12M4 20.5h16"/>'
        f'<path {fill} d="M12 12c-4 0-6-2.5-6-6 4 0 6 2.5 6 6zM12 11c0-3.5 2-5.5 6-5.5 0 3.5-2 5.5-6 5.5z"/>',
        "burning": f'<path {fill} d="M12 2.5c1.6 4.6 6.5 6.4 6.5 12a6.5 6.5 0 0 1-13 0c0-3.2 1.6-4.8 3.2-6.4 0 3.2 1.6 4.8 3.2 4.8 0-4.8-1.6-6.4.1-10.4z"/>',
        "ruins": f'<path {stroke} stroke-width="2.2" d="M3.5 20h17M5.5 20v-7l4.5-3.5V20M14 20V8.5l5 4V20"/>',
    }


# Pictogram, its disc colour, and whether a slash crosses it (something is missing).
PICTOGRAMS: dict[str, tuple[str, bool]] = {
    "no-road": (RED, True),
    "no-route": (RED, True),
    "no-trees": (RED, True),
    "no-room-to-plant": (RED, True),
    # Seasonal events (add-event-counterplay): a building on fire, and ruins to clear.
    "burning": (RED, False),
    "ruins": (RED, False),
}

# Seasonal-event hazards on a cream disc, like a good's issue: the glyph, and the pip's kind. A blight
# slows a field (amber pause); a fever holds a house back (red "!"). Glyphs on a 24-unit grid.
HAZARDS: dict[str, tuple[str, str]] = {
    "blight": (
        '<path fill="#8a7a2a" stroke="#5c5018" stroke-width="1" d="M5 21c0-9 6-14 14-16-1.5 9-6 15-14 16z"/>'
        '<path fill="none" stroke="#5c5018" stroke-width="1.2" stroke-linecap="round" d="M5 21 14 10"/>'
        '<circle fill="#6b4a1e" cx="11" cy="13" r="1.4"/><circle fill="#6b4a1e" cx="14.5" cy="10.5" r="1.1"/>',
        "stuck",
    ),
    "fever": (
        '<rect fill="#ffffff" stroke="#7a3b2a" stroke-width="1.6" x="9.5" y="2.5" width="5" height="13" rx="2.5"/>'
        '<circle fill="#c8402e" stroke="#7a3b2a" stroke-width="1.6" cx="12" cy="18" r="4"/>'
        '<rect fill="#c8402e" x="11" y="8" width="2" height="9"/>',
        "short",
    ),
}

# Good variants: the pip's colour and glyph.
PIPS: dict[str, str] = {"short": RED, "stuck": AMBER}


def _svg(body: str) -> str:
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" viewBox="0 0 {SIZE} {SIZE}">{body}</svg>'


def pictogram(name: str) -> str:
    colour, slash = PICTOGRAMS[name]
    body = [
        f'<circle fill="{colour}" stroke="{OUTLINE}" stroke-width="1.6" cx="14" cy="14" r="12"/>',
        f'<path fill="{WHITE}" fill-opacity=".22" d="M5 11a9.5 9.5 0 0 1 18 0c-5-2-13-2-18 0z"/>',
        f'<g transform="translate(6.6 6.6) scale(0.62)">{_glyphs(WHITE)[name]}',
    ]
    if slash:
        body.append(f'<path fill="none" stroke="{WHITE}" stroke-width="2.4" stroke-linecap="round" d="M4.5 4.5l15 15"/>')
    body.append("</g>")
    return _svg("".join(body))


def _pip(kind: str, cx: float = 21.5, cy: float = 21.5, r: float = 5.2) -> str:
    disc = f'<circle fill="{PIPS[kind]}" stroke="{OUTLINE}" stroke-width="1.2" cx="{cx}" cy="{cy}" r="{r}"/>'
    if kind == "short":
        glyph = (
            f'<path fill="none" stroke="{WHITE}" stroke-width="2.18" stroke-linecap="round" d="M{cx} 18.9v2.86"/>'
            f'<circle fill="{WHITE}" cx="{cx}" cy="24.1" r="1.14"/>'
        )
    else:
        glyph = f'<rect fill="{WHITE}" x="19.16" y="19.16" width="1.56" height="4.68"/><rect fill="{WHITE}" x="22.28" y="19.16" width="1.56" height="4.68"/>'
    return disc + glyph


def _cream_icon(inner: str, kind: str) -> str:
    """A 24-unit glyph on the cream disc, with a pip of `kind` in the lower right."""
    return _svg(
        f'<circle fill="{CREAM}" stroke="{OUTLINE}" stroke-width="1.6" cx="13" cy="13" r="11"/>'
        f'<g transform="translate(4.8 4.8) scale(0.68)">{inner}</g>'
        + _pip(kind)
    )


def good_icon(good: str, kind: str) -> str:
    return _cream_icon(re.sub(r"^<svg[^>]*>|</svg>$", "", goods_icons.svg(good)), kind)


def hazard_icon(name: str) -> str:
    return _cream_icon(*HAZARDS[name])


def sources() -> dict[str, str]:
    """Every status icon: `status-<pictogram>`, `status-<hazard>` and `status-<good>-short` / `-stuck`."""
    icons = {f"status-{name}": pictogram(name) for name in PICTOGRAMS}
    icons.update({f"status-{name}": hazard_icon(name) for name in HAZARDS})
    for good in goods_icons.GLYPHS:
        for kind in PIPS:
            icons[f"status-{good}-{kind}"] = good_icon(good, kind)
    return icons
