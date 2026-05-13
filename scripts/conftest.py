"""Pytest fixtures + sys.path shim for the sprite generation pipeline.

Tests live under `scripts/tests/`; the modules they import (`composer`,
`slicer`, `postprocess`, …) live under `scripts/generate_sprites_ai/`.
Pytest finds this conftest.py via rootdir discovery when invoked from
`scripts/` (the `make sprites-test` target `cd`s here first).
"""

from __future__ import annotations

import os
import sys

# Make the pipeline package importable as `generate_sprites_ai.*` when
# pytest is invoked with `scripts/` as the working directory.
_HERE = os.path.dirname(os.path.abspath(__file__))
if _HERE not in sys.path:
    sys.path.insert(0, _HERE)
