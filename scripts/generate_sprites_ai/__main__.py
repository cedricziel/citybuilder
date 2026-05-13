"""CLI entry point for the AI sprite generation pipeline.

Usage:
    python -m generate_sprites_ai [--offline] [--regenerate-reference]
                                  [--verify]
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
    cfg = _load_pipeline_toml()
    model_id = cfg["model"]
    world_md = paths.WORLD_MD.read_text(encoding="utf-8")
    print(f"generating master reference via {model_id} ...", flush=True)
    img = generate_master_reference(world_md, model_id=model_id)
    paths.STYLE_DIR.mkdir(parents=True, exist_ok=True)
    img.save(paths.MASTER_REFERENCE, format="PNG")
    print(f"wrote {paths.MASTER_REFERENCE}", flush=True)
    return 0


def _cmd_sprites(offline: bool, verify: bool) -> int:
    # Lazy import — keeps the reference-only path lightweight.
    from .batcher import run_pipeline

    return run_pipeline(offline=offline, verify=verify)


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
    args = p.parse_args(argv)

    if args.regenerate_reference:
        return _cmd_regenerate_reference()
    return _cmd_sprites(offline=args.offline, verify=args.verify)


if __name__ == "__main__":
    sys.exit(main())
