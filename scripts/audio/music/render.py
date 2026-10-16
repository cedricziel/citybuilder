"""Renders every piece into Resources/Audio/music.

    cd scripts && python3 -m audio.music.render            # write
    cd scripts && python3 -m audio.music.render --check    # compare
    cd scripts && python3 -m audio.music.render --only music/x.caf  # one piece
"""

from __future__ import annotations

import argparse
import json
import sys

from audio import caf, generate
from audio.music import pieces, score, synth

AUTHOR = "Citybuilder original score"


def manifest_entry(piece: score.Piece) -> dict[str, str]:
    return {"path": piece.path, "title": piece.title + " (original, generated in-repo)", "author": AUTHOR,
            "source": generate.SOURCE + "/music", "license": "CC0"}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--only")
    args = parser.parse_args(argv)
    if args.only and args.only not in {piece.path for piece in pieces.PIECES}:
        parser.error(f"no piece renders to {args.only}")
    stale = []
    for piece in pieces.PIECES:
        if args.only and piece.path != args.only:
            continue
        data = caf.write_caf(score.render(piece), synth.SR)
        target = generate.AUDIO_DIR / piece.path
        if args.check:
            if not target.exists() or target.read_bytes() != data:
                stale.append(piece.path)
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
            print(f"wrote {piece.path} ({len(data)} bytes)")
    manifest = json.loads(generate.MANIFEST.read_text(encoding="utf-8"))
    updated = generate.updated_manifest(manifest, {p.path: manifest_entry(p) for p in pieces.PIECES})
    if args.check and updated != manifest:
        stale.append("manifest.json")
    elif not args.check:
        generate.MANIFEST.write_text(json.dumps(updated, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    for path in stale:
        print(f"stale: {path} differs from its score; run `make music`", file=sys.stderr)
    return 1 if stale else 0


if __name__ == "__main__":
    sys.exit(main())
