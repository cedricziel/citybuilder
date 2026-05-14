"""Pure-function tests for `generate_sprites_ai.composer`.

`compose_prompt` MUST be a pure function — same inputs produce equal
output bytes — so the cache key (a sha256 of the prompt + fixed
instructions + model id) stays stable across machines.
"""

from __future__ import annotations

from generate_sprites_ai.composer import compose_prompt, FIXED_INSTRUCTIONS


WORLD_FIXTURE = """\
## Theme & era
A coastal medieval town.

## Palette
- `#7A1F1A` terracotta.

## Background
Generated PNGs ship with real transparency. The API is called with
`background: "transparent"`; pixels outside the silhouette are alpha=0.
"""

ENTRY_FIXTURE = """\
## Function
Lumberjack hut.

## Visual identity
Small thatched shed.

## Sheet
Grid: 4 cols × 2 rows.
- (0, 0): `building-lumberjack-hut`

## Animation
- Construction: `(0, 1)` → `(0, 2)`.
"""


def test_compose_prompt_returns_string() -> None:
    out = compose_prompt(WORLD_FIXTURE, ENTRY_FIXTURE, FIXED_INSTRUCTIONS)
    assert isinstance(out, str)
    assert out, "prompt must be non-empty"


def test_compose_prompt_is_pure() -> None:
    a = compose_prompt(WORLD_FIXTURE, ENTRY_FIXTURE, FIXED_INSTRUCTIONS)
    b = compose_prompt(WORLD_FIXTURE, ENTRY_FIXTURE, FIXED_INSTRUCTIONS)
    assert a == b


def test_compose_prompt_includes_world_and_entry_content() -> None:
    out = compose_prompt(WORLD_FIXTURE, ENTRY_FIXTURE, FIXED_INSTRUCTIONS)
    assert "coastal medieval town" in out
    assert "Lumberjack hut" in out


def test_compose_prompt_pins_transparent_background_in_fixed_instructions() -> None:
    # Fixed instructions MUST tell the model to emit a transparent
    # background. The image API also gets `background: "transparent"`
    # as a parameter, but the prompt-side directive is what stops the
    # model from painting opaque scenery around the sprite.
    out = compose_prompt(WORLD_FIXTURE, ENTRY_FIXTURE, FIXED_INSTRUCTIONS)
    lower = out.lower()
    assert "transparent" in lower
    assert "alpha=0" in lower or "alpha = 0" in lower


def test_compose_prompt_differs_when_world_changes() -> None:
    a = compose_prompt(WORLD_FIXTURE, ENTRY_FIXTURE, FIXED_INSTRUCTIONS)
    b = compose_prompt(WORLD_FIXTURE + "\nextra", ENTRY_FIXTURE, FIXED_INSTRUCTIONS)
    assert a != b


def test_compose_prompt_differs_when_entry_changes() -> None:
    a = compose_prompt(WORLD_FIXTURE, ENTRY_FIXTURE, FIXED_INSTRUCTIONS)
    b = compose_prompt(WORLD_FIXTURE, ENTRY_FIXTURE + "\nextra", FIXED_INSTRUCTIONS)
    assert a != b
