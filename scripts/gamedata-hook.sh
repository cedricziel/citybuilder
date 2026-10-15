#!/usr/bin/env bash
# Claude Code edit hook for the game data, wired in .claude/settings.json.
#   pre  — blocks hand edits under Packages/CityCore/Sources/CityCore/Generated/
#   post — validates the packs after an edit under Packages/CityCore/GameData/
#
# It runs for every agent edit in the repository, so it stays narrow:
# input that doesn't mention either directory exits 0 before anything
# else runs. It also fails open: when the generator can't be built or
# run, the edit goes through. Only `gamedata-gen hook`'s exit 2 blocks
# an edit (pre) or reports back to the agent (post); stderr carries why.
set -uo pipefail

phase=${1:-}
input=$(cat) || exit 0
case "$input" in
    *Packages/CityCore/GameData/* | *Packages/CityCore/Sources/CityCore/Generated/*) ;;
    *) exit 0 ;;
esac

cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/..}" 2>/dev/null || exit 0
swift=(swift)
if command -v xcrun >/dev/null 2>&1; then swift=(xcrun swift); fi
# Debug, like `make gamedata`, so both share one incremental build.
"${swift[@]}" build -q --package-path Packages/GameDataGen --product gamedata-gen >/dev/null 2>&1 || exit 0
bin=Packages/GameDataGen/.build/debug/gamedata-gen
[ -x "$bin" ] || exit 0

printf '%s' "$input" | "$bin" hook "$phase"
[ $? -eq 2 ] && exit 2
exit 0
