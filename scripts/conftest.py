"""Pytest fixtures + sys.path shim for the art pipeline and the audio tools.

Tests live under `scripts/tests/`; the modules they import live under
`scripts/art/` and `scripts/audio/`. Pytest finds this conftest.py via
rootdir discovery when invoked from `scripts/` (the `make sprites-test`
target `cd`s here first).
"""

from __future__ import annotations

import os
import sys

# Make `art.*` and `audio.*` importable when pytest is invoked with
# `scripts/` as the working directory.
_HERE = os.path.dirname(os.path.abspath(__file__))
if _HERE not in sys.path:
    sys.path.insert(0, _HERE)


def pytest_configure(config) -> None:  # noqa: ANN001 - pytest hook
    # `@pytest.mark.scenario("Title")` maps a test to an OpenSpec scenario;
    # scripts/check-scenario-coverage.swift reads it.
    config.addinivalue_line("markers", "scenario(title): the OpenSpec scenario this test covers")
    config.addinivalue_line("markers", "slow: renders a lot; skipped unless AUDIO_SLOW_TESTS is set")
