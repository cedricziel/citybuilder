"""CLI entry point for the AI sprite generation pipeline.

Usage:
    python -m generate_sprites_ai [--offline] [--regenerate-reference]
                                  [--verify] [--procedural]
"""

from __future__ import annotations

import argparse
import sys
import tomllib

from . import paths
from .reference import generate_master_reference


def _load_pipeline_toml() -> dict:
    with paths.PIPELINE_TOML.open("rb") as f:
        return tomllib.load(f)


def _cmd_regenerate_reference() -> int:
    from .cache import _save_indexed
    from .postprocess import threshold_alpha

    cfg = _load_pipeline_toml()
    model_id = cfg["model"]
    threshold = int(cfg.get("alpha_threshold", 128))
    world_md = paths.WORLD_MD.read_text(encoding="utf-8")
    print(f"generating master reference via {model_id} ...", flush=True)
    raw = generate_master_reference(world_md, model_id=model_id)
    # Threshold the soft alpha returned by the model to binary 0/255
    # so the anchor image carries the same crisp-edge convention every
    # downstream sprite inherits, and save as an indexed PNG to keep
    # the committed binary well under the 1 MB pre-commit cap.
    binarised = threshold_alpha(raw, threshold=threshold)
    paths.STYLE_DIR.mkdir(parents=True, exist_ok=True)
    _save_indexed(binarised, paths.MASTER_REFERENCE)
    print(f"wrote {paths.MASTER_REFERENCE}", flush=True)
    return 0


def _cmd_sprites(offline: bool, verify: bool) -> int:
    # Lazy import — keeps the reference-only path lightweight.
    from .batcher import run_pipeline

    return run_pipeline(offline=offline, verify=verify)


def _cmd_procedural() -> int:
    from .batcher import run_pipeline, write_procedural_sheets

    written = write_procedural_sheets()
    print(f"[procedural] wrote {len(written)} sheet(s)", flush=True)
    return run_pipeline(offline=True)


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(prog="generate_sprites_ai")
    p.add_argument(
        "--offline",
        action="store_true",
        help="read sprite sheets only from committed _sheets/; do not "
        "call the OpenAI API",
    )
    p.add_argument(
        "--regenerate-reference",
        action="store_true",
        help="regenerate Resources/Sprites.style/master-reference.png "
        "via /v1/images/generations and exit. This is the only path "
        "that touches master-reference.png.",
    )
    p.add_argument(
        "--verify",
        action="store_true",
        help="run sprites in --offline mode against a scratch directory "
        "and diff against the committed atlas PNGs. Exits non-zero on "
        "any diff.",
    )
    p.add_argument(
        "--procedural",
        action="store_true",
        help="redraw the _sheets/ of every `source = \"procedural\"` "
        "catalog entry locally, then regenerate all atlases offline. "
        "Needs no API key.",
    )
    args = p.parse_args(argv)

    if args.regenerate_reference:
        return _cmd_regenerate_reference()
    if args.procedural:
        return _cmd_procedural()
    return _cmd_sprites(offline=args.offline, verify=args.verify)


if __name__ == "__main__":
    sys.exit(main())
