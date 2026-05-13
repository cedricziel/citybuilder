"""Tests for `generate_sprites_ai.cache`.

`cache_key(...)` MUST be deterministic and MUST incorporate every
input that should invalidate the cache (world.md, entry.md, fixed
instructions, model id). `read_cache` / `write_cache` round-trip a
Pillow image through a content-addressed file.
"""

from __future__ import annotations

from pathlib import Path

import pytest
from PIL import Image

from generate_sprites_ai.cache import (
    cache_key,
    read_cache,
    write_cache,
)


WORLD = "## Theme\nMedieval coastal town."
ENTRY = "## Function\nA house."
INSTRUCTIONS = "Generate one sprite sheet."
MODEL = "gpt-image-2-2026-04-21"


def test_cache_key_is_deterministic() -> None:
    a = cache_key(WORLD, ENTRY, INSTRUCTIONS, MODEL)
    b = cache_key(WORLD, ENTRY, INSTRUCTIONS, MODEL)
    assert a == b
    assert len(a) == 64  # sha256 hex digest


def test_cache_key_changes_when_world_changes() -> None:
    a = cache_key(WORLD, ENTRY, INSTRUCTIONS, MODEL)
    b = cache_key(WORLD + "\nextra", ENTRY, INSTRUCTIONS, MODEL)
    assert a != b


def test_cache_key_changes_when_entry_changes() -> None:
    a = cache_key(WORLD, ENTRY, INSTRUCTIONS, MODEL)
    b = cache_key(WORLD, ENTRY + "\nextra", INSTRUCTIONS, MODEL)
    assert a != b


def test_cache_key_changes_when_model_changes() -> None:
    a = cache_key(WORLD, ENTRY, INSTRUCTIONS, MODEL)
    b = cache_key(WORLD, ENTRY, INSTRUCTIONS, "gpt-image-3-2030-01-01")
    assert a != b


def test_cache_key_changes_when_instructions_change() -> None:
    a = cache_key(WORLD, ENTRY, INSTRUCTIONS, MODEL)
    b = cache_key(WORLD, ENTRY, INSTRUCTIONS + " extra", MODEL)
    assert a != b


def test_cache_key_only_one_entry_changes_when_one_entry_edited() -> None:
    """The single-entry-edit invalidation scenario: editing one
    catalog entry MUST invalidate only that entry's cache key, leaving
    every other entry's key unchanged."""
    keys = []
    for entry_text in ("entry-a", "entry-b", "entry-c"):
        keys.append(cache_key(WORLD, entry_text, INSTRUCTIONS, MODEL))
    # Now edit entry-b only.
    new_keys = [
        cache_key(WORLD, "entry-a", INSTRUCTIONS, MODEL),
        cache_key(WORLD, "entry-b-edited", INSTRUCTIONS, MODEL),
        cache_key(WORLD, "entry-c", INSTRUCTIONS, MODEL),
    ]
    assert new_keys[0] == keys[0]
    assert new_keys[1] != keys[1]
    assert new_keys[2] == keys[2]


def test_cache_roundtrip(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    """write_cache then read_cache returns an image with equal pixels.
    The cache dir is redirected to tmp_path so the test never touches
    the real Resources/Sprites.style/_cache/."""
    monkeypatch.setattr(
        "generate_sprites_ai.cache.CACHE_DIR_OVERRIDE", tmp_path, raising=False
    )
    img = Image.new("RGBA", (4, 4), (255, 0, 255, 255))
    img.putpixel((1, 1), (10, 20, 30, 255))
    key = cache_key(WORLD, ENTRY, INSTRUCTIONS, MODEL)
    assert read_cache(key) is None  # empty initially
    write_cache(key, img, api_response_json={"data": [{"b64_json": "..."}]})
    out = read_cache(key)
    assert out is not None
    assert out.size == img.size
    # Bytes equal — chroma-key sentinel preserved.
    assert list(out.convert("RGBA").getdata()) == list(img.convert("RGBA").getdata())


def test_cache_miss_returns_none(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(
        "generate_sprites_ai.cache.CACHE_DIR_OVERRIDE", tmp_path, raising=False
    )
    assert read_cache("a" * 64) is None
