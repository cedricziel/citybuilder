"""Renders every procedural sound into Resources/Audio.

    cd scripts && python3 -m audio.generate          # write the files
    cd scripts && python3 -m audio.generate --check  # fail if any differs

Pure standard-library Python with our own sine and exponential, so the
bytes are the same on every machine and every Python from 3.9 on
(checked with 3.9, 3.10 and 3.14; avoid built-in sum() on floats, which
3.12 changed).
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from audio import caf, sounds

AUDIO_DIR = Path(__file__).resolve().parents[2] / "Resources" / "Audio"
MANIFEST = AUDIO_DIR / "manifest.json"
SOURCE = "https://github.com/cedricziel/citybuilder/tree/main/scripts/audio"


def render_bytes(sound: sounds.Sound) -> bytes:
    return caf.write_caf(sounds.render(sound), sounds.SR)


def manifest_entry(sound: sounds.Sound) -> dict[str, str]:
    return {"path": sound.path, "title": sound.title, "author": "Citybuilder sound generator",
            "source": SOURCE, "license": "CC0"}


def updated_manifest(manifest: dict, generated: dict[str, dict] | None = None) -> dict:
    """The manifest with `generated` entries (by default every sound's):
    an existing entry for the path is replaced where it stands, a new one
    is appended, so generators that share the manifest don't reorder it."""
    if generated is None:
        generated = {sound.path: manifest_entry(sound) for sound in sounds.SOUNDS}
    entries = [generated.get(entry["path"], entry) for entry in manifest["entries"]]
    present = {entry["path"] for entry in entries}
    entries += [entry for path, entry in generated.items() if path not in present]
    return {**manifest, "entries": entries}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="compare with the committed files instead of writing")
    parser.add_argument("--only", help="render only the sound at this path, e.g. loop/sawmill.caf")
    args = parser.parse_args(argv)
    stale = []
    for sound in sounds.SOUNDS:
        if args.only and sound.path != args.only:
            continue
        data = render_bytes(sound)
        target = AUDIO_DIR / sound.path
        if args.check:
            if not target.exists() or target.read_bytes() != data:
                stale.append(sound.path)
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
            print(f"wrote {sound.path} ({len(data)} bytes)")
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    wanted = updated_manifest(manifest)
    if args.check:
        if wanted != manifest:
            stale.append("manifest.json")
    else:
        MANIFEST.write_text(json.dumps(wanted, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    for path in stale:
        print(f"stale: {path} differs from its recipe; run `make audio`", file=sys.stderr)
    return 1 if stale else 0


if __name__ == "__main__":
    sys.exit(main())
