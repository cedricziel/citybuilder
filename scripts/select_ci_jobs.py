"""Select the CI jobs a change's files need.

Reads changed paths (one per line, from `git diff --no-renames
--name-only`) on stdin and prints GitHub step outputs. The paths are a
PR's diff against its base, or a push to main's diff against the head
of the latest green run on main. ci.yml selects everything itself,
without this script, when there is nothing to diff against (the weekly
schedule, a manual run, no usable green run) and for changes to this
script, its tests or the workflow.

- Docs only (`openspec/`, `.claude/`, top-level `*.md` but README.md):
  no code jobs.
- A file under `Packages/<P>/` affects P and every package that depends
  on P, directly or transitively, per the `.package(path:)` entries in
  each `Packages/*/Package.swift`. CityCore affects every package:
  GameDataGen writes CityCore's generated sources.
- Anything else (apps, `project.yml`, `Resources/`, scripts, the
  Makefile, workflows) selects everything.

The app builds run when a package listed under `packages:` in
`project.yml` is affected. The gamedata fixture build runs when
GameDataGen or a package `scripts/check-gamedata-fixture-build.sh`
builds is affected. Linux determinism runs for CityCore or GameDataGen;
the macOS-vs-Linux comparison needs the CityCore test job's output, so
it runs for CityCore only. The audio render check runs when everything
does: its sources (`scripts/audio/`) and renders (`Resources/Audio/`)
are outside the packages.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path

# README.md is not docs-only: SpritesPipelineCutoverTests reads it.
DOCS_ONLY = re.compile(r"^(openspec/|\.claude/|(?!README\.md$)[^/]+\.md$)")
PACKAGE_CALL = re.compile(r"\.package\(([^)]*)\)")
LOCAL_DEPENDENCY = re.compile(r'\s*path:\s*"\.\./([^"/]+)"\s*')
FIXTURE_PACKAGES = re.compile(r"^for package in ([^;]+); do$", re.M)


@dataclass(frozen=True)
class Jobs:
    packages: list[str]
    apps: bool
    sprites: bool
    gamedata_fixture: bool
    determinism_linux: bool
    determinism_compare: bool
    audio: bool

    def github_output(self) -> str:
        def flag(value: bool) -> str:
            return "true" if value else "false"

        return "\n".join([
            f"packages={json.dumps(self.packages)}",
            f"apps={flag(self.apps)}",
            f"sprites={flag(self.sprites)}",
            f"gamedata_fixture={flag(self.gamedata_fixture)}",
            f"determinism_linux={flag(self.determinism_linux)}",
            f"determinism_compare={flag(self.determinism_compare)}",
            f"audio={flag(self.audio)}",
        ]) + "\n"


def _local_dependencies(manifest: Path) -> set[str]:
    """The packages a manifest's `.package(path: "../X")` entries name.

    Raises on any other form of a local dependency rather than dropping
    an edge, which would deselect the dependent's tests."""
    uses = set()
    for args in PACKAGE_CALL.findall(manifest.read_text(encoding="utf-8")):
        if "path:" not in args:
            continue
        match = LOCAL_DEPENDENCY.fullmatch(args)
        if match is None:
            raise ValueError(
                f"{manifest.parent.name}: cannot read `.package({args})`; "
                'write it as `.package(path: "../Name")`'
            )
        uses.add(match.group(1))
    return uses


def dependencies(root: Path) -> dict[str, set[str]]:
    """Each package's direct local dependencies."""
    graph = {
        manifest.parent.name: _local_dependencies(manifest)
        for manifest in (root / "Packages").glob("*/Package.swift")
    }
    for name, uses in graph.items():
        if unknown := uses - graph.keys():
            raise ValueError(f"{name} depends on unknown packages: {sorted(unknown)}")
    return graph


def app_packages(root: Path) -> set[str]:
    """Packages the Xcode project links, from `project.yml`'s `packages:`."""
    text = (root / "project.yml").read_text(encoding="utf-8")
    block = re.search(r"^packages:\n((?:[ \t].*\n|\n)*)", text, re.M)
    if block is None:
        raise ValueError("project.yml has no top-level packages: section")
    return set(re.findall(r"^  ([A-Za-z0-9_]+):", block.group(1), re.M))


def fixture_packages(root: Path) -> set[str]:
    text = (root / "scripts" / "check-gamedata-fixture-build.sh").read_text(encoding="utf-8")
    match = FIXTURE_PACKAGES.search(text)
    if match is None:
        raise ValueError("check-gamedata-fixture-build.sh: no `for package in ...` loop")
    return set(match.group(1).split()) | {"GameDataGen"}


def _jobs(root: Path, affected: set[str], everything: bool) -> Jobs:
    return Jobs(
        packages=sorted(affected),
        apps=everything or bool(affected & app_packages(root)),
        sprites=everything,
        gamedata_fixture=everything or bool(affected & fixture_packages(root)),
        determinism_linux=everything or bool(affected & {"CityCore", "GameDataGen"}),
        determinism_compare=everything or "CityCore" in affected,
        # The audio sources and renders live outside Packages/, so only a
        # change that selects everything can touch them.
        audio=everything,
    )


def everything(root: Path) -> Jobs:
    return _jobs(root, set(dependencies(root)), everything=True)


def select(changed: list[str], root: Path) -> Jobs:
    graph = dependencies(root)
    if not changed:
        return everything(root)
    code_files = [path for path in changed if not DOCS_ONLY.match(path)]
    if not code_files:
        return Jobs([], False, False, False, False, False, False)

    touched: set[str] = set()
    for path in code_files:
        parts = path.split("/")
        if parts[0] != "Packages" or len(parts) < 3 or parts[1] not in graph:
            return everything(root)
        touched.add(parts[1])
    if "CityCore" in touched:
        return _jobs(root, set(graph), everything=False)

    affected = set(touched)
    while True:
        dependents = {name for name, uses in graph.items() if uses & affected} - affected
        if not dependents:
            break
        affected |= dependents
    return _jobs(root, affected, everything=False)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parent.parent)
    args = parser.parse_args(argv)
    jobs = select([line for line in sys.stdin.read().splitlines() if line], args.root)
    sys.stdout.write(jobs.github_output())
    return 0


if __name__ == "__main__":
    sys.exit(main())
