"""Only `--regenerate-reference` writes master-reference.png.

Runs the offline regen against a one-entry catalog with every output
redirected into tmp_path, so the test never rewrites the committed
atlas PNGs.
"""

from __future__ import annotations

import shutil
from pathlib import Path

import pytest

from generate_sprites_ai import paths
from generate_sprites_ai.__main__ import main


def test_offline_regen_leaves_the_master_reference_alone(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    catalog = tmp_path / "catalog"
    catalog.mkdir()
    shutil.copy(paths.CATALOG_DIR / "good-wood.md", catalog)
    reference = tmp_path / "master-reference.png"
    shutil.copy(paths.MASTER_REFERENCE, reference)
    before = reference.stat().st_mtime_ns
    monkeypatch.setattr(paths, "CATALOG_DIR", catalog)
    monkeypatch.setattr(paths, "MASTER_REFERENCE", reference)
    monkeypatch.setattr(paths, "ATLAS_DIRS", {"good-": tmp_path / "Icons.atlas"})

    assert main(["--offline"]) == 0

    assert (tmp_path / "Icons.atlas" / "good-wood.png").exists()
    assert reference.stat().st_mtime_ns == before
