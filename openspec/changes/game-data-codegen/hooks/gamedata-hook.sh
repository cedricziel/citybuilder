#!/usr/bin/env bash
# Claude Code hook for content packs (draft; lands as scripts/gamedata-hook.sh).
#   pre  — blocks hand edits to Packages/CityCore/Sources/CityCore/Generated/
#   post — validates the packs after an edit under Packages/CityCore/GameData/
# Hook JSON arrives on stdin and `gamedata-gen hook` parses it, so no jq is
# needed. Exit 2 sends stderr back to the agent; exit 0 lets the call through.
set -euo pipefail
input=$(cat)
case "$input" in
    *Packages/CityCore/GameData/* | *Sources/CityCore/Generated/*) ;;
    *) exit 0 ;;
esac
cd "$CLAUDE_PROJECT_DIR"
bin=Packages/GameDataGen/.build/release/gamedata-gen
swift=$(command -v xcrun >/dev/null && echo "xcrun swift" || echo swift)
if [ ! -x "$bin" ]; then
    $swift build -c release --package-path Packages/GameDataGen --product gamedata-gen >&2
fi
printf '%s' "$input" | "$bin" hook "$1"
