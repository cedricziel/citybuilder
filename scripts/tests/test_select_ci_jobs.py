"""Which CI jobs a set of changed files selects."""

from __future__ import annotations

import json
import re
from pathlib import Path

import pytest

import select_ci_jobs
from select_ci_jobs import select

ALL_PACKAGES = [
    "CityAudio", "CityCore", "CityPersistence", "CityRender2D",
    "CityRender3D", "CityUI", "GameDataGen",
]
APP_PACKAGES = [p for p in ALL_PACKAGES if p != "GameDataGen"]


@pytest.fixture
def repo(tmp_path: Path) -> Path:
    """A repository whose package graph matches the real one."""
    deps = {
        "CityCore": [],
        "CityPersistence": ["CityCore"],
        "CityUI": ["CityCore"],
        "CityRender2D": ["CityCore"],
        "CityRender3D": ["CityCore"],
        "CityAudio": ["CityCore", "CityPersistence", "CityUI"],
        "GameDataGen": [],
    }
    for name, uses in deps.items():
        package = tmp_path / "Packages" / name
        package.mkdir(parents=True)
        lines = ",\n".join(f'        .package(path: "../{u}")' for u in uses)
        (package / "Package.swift").write_text(
            f'let package = Package(\n    name: "{name}",\n    dependencies: [\n{lines}\n    ]\n)\n'
        )
    linked = "".join(f"  {n}:\n    path: Packages/{n}\n" for n in APP_PACKAGES)
    (tmp_path / "project.yml").write_text(f"name: X\npackages:\n{linked}\ntargets:\n  App:\n    type: application\n")
    (tmp_path / "scripts").mkdir()
    (tmp_path / "scripts" / "check-gamedata-fixture-build.sh").write_text(
        "for package in CityCore CityUI CityRender2D; do\n    rsync\ndone\n"
    )
    return tmp_path


def test_a_cityaudio_change_runs_only_cityaudio(repo: Path) -> None:
    jobs = select(["Packages/CityAudio/Sources/CityAudio/Mixer.swift"], repo)

    assert jobs.packages == ["CityAudio"]
    assert jobs.apps
    assert not jobs.sprites
    assert not jobs.gamedata_fixture
    assert not jobs.determinism_linux
    assert not jobs.determinism_compare


def test_a_citycore_change_runs_everything_but_the_sprite_pytest(repo: Path) -> None:
    jobs = select(["Packages/CityCore/Sources/CityCore/Tick.swift"], repo)

    assert jobs.packages == ALL_PACKAGES
    assert jobs.apps
    assert jobs.gamedata_fixture
    assert jobs.determinism_linux
    assert jobs.determinism_compare
    assert not jobs.sprites


def test_a_dependency_change_runs_its_transitive_dependents(repo: Path) -> None:
    jobs = select(["Packages/CityUI/Sources/CityUI/HUD.swift"], repo)

    assert jobs.packages == ["CityAudio", "CityUI"]
    assert jobs.gamedata_fixture


def test_a_gamedatagen_change_skips_the_apps_and_the_macos_determinism(repo: Path) -> None:
    jobs = select(["Packages/GameDataGen/Sources/gamedata-gen/main.swift"], repo)

    assert jobs.packages == ["GameDataGen"]
    assert not jobs.apps
    assert jobs.gamedata_fixture
    assert jobs.determinism_linux
    assert not jobs.determinism_compare


def test_a_docs_only_change_runs_no_code_jobs(repo: Path) -> None:
    jobs = select(["CHANGELOG.md", "openspec/specs/x/spec.md", ".claude/notes.md"], repo)

    assert jobs.packages == []
    assert not (jobs.apps or jobs.sprites or jobs.gamedata_fixture)
    assert not (jobs.determinism_linux or jobs.determinism_compare)


@pytest.mark.parametrize("path", [
    "Apps/iOS/ContentView.swift",
    "project.yml",
    "Resources/Buildings.atlas/building-house.png",
    "scripts/check-coverage.sh",
    "Makefile",
    ".github/workflows/ci.yml",
    "Packages/README.md",
    # SpritesPipelineCutoverTests reads it.
    "README.md",
])
def test_a_change_outside_the_packages_runs_everything(repo: Path, path: str) -> None:
    jobs = select([path, "Packages/CityAudio/Sources/CityAudio/Mixer.swift"], repo)

    assert jobs == select_ci_jobs.everything(repo)
    assert jobs.packages == ALL_PACKAGES
    assert jobs.apps and jobs.sprites and jobs.gamedata_fixture
    assert jobs.determinism_linux and jobs.determinism_compare


def test_a_rename_across_packages_runs_both_sides(repo: Path) -> None:
    # `git diff --no-renames` lists a move as a delete plus an add.
    jobs = select([
        "Packages/CityRender3D/Sources/CityRender3D/Camera.swift",
        "Packages/CityPersistence/Sources/CityPersistence/Camera.swift",
    ], repo)

    assert jobs.packages == ["CityAudio", "CityPersistence", "CityRender3D"]


def test_no_changed_files_runs_everything(repo: Path) -> None:
    assert select([], repo) == select_ci_jobs.everything(repo)


def test_the_output_is_github_output_lines(repo: Path) -> None:
    lines = select(["Packages/CityAudio/Package.swift"], repo).github_output().splitlines()

    assert "sprites=false" in lines
    assert "apps=true" in lines
    packages = next(line for line in lines if line.startswith("packages="))
    assert json.loads(packages.removeprefix("packages=")) == ["CityAudio"]


@pytest.mark.parametrize("declaration", [
    '.package(name: "CityCore", path: "../CityCore")',
    '.package(path: "../CityCore/")',
    ".package(path: corePath)",
])
def test_a_local_dependency_the_parser_cannot_read_fails(repo: Path, declaration: str) -> None:
    manifest = repo / "Packages" / "CityUI" / "Package.swift"
    manifest.write_text(manifest.read_text().replace('.package(path: "../CityCore")', declaration))

    with pytest.raises(ValueError, match="CityUI"):
        select(["Packages/CityUI/Sources/CityUI/HUD.swift"], repo)


def test_a_remote_dependency_is_not_a_local_edge(repo: Path) -> None:
    manifest = repo / "Packages" / "GameDataGen" / "Package.swift"
    manifest.write_text(manifest.read_text().replace(
        "dependencies: [\n", 'dependencies: [\n        .package(url: "https://github.com/jpsim/Yams.git", exact: "6.2.2")\n'
    ))

    assert select(["Packages/GameDataGen/Package.swift"], repo).packages == ["GameDataGen"]


def test_a_dependency_on_an_unknown_package_fails(repo: Path) -> None:
    manifest = repo / "Packages" / "CityUI" / "Package.swift"
    manifest.write_text(manifest.read_text().replace("../CityCore", "../Gone"))

    with pytest.raises(ValueError, match="Gone"):
        select(["Packages/CityUI/Sources/CityUI/HUD.swift"], repo)


def test_the_real_manifests_parse() -> None:
    root = Path(__file__).resolve().parents[2]

    assert select(["Packages/CityPersistence/Package.swift"], root).packages == [
        "CityAudio", "CityPersistence",
    ]
    assert select(["Packages/CityCore/Package.swift"], root).packages == sorted(
        p.parent.name for p in (root / "Packages").glob("*/Package.swift")
    )


def test_the_workflow_selects_everything_with_the_same_outputs() -> None:
    root = Path(__file__).resolve().parents[2]
    workflow = (root / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
    shell_keys = re.findall(r'^ +echo "([a-z_]+)=', workflow, re.M)
    output = select_ci_jobs.everything(root).github_output()

    assert shell_keys == [line.split("=", 1)[0] for line in output.splitlines()]
