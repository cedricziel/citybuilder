#!/usr/bin/env bash
# Claude Code edit hook for the game data, wired in .claude/settings.json
# to the Edit, Write and MultiEdit tools.
#   pre  — blocks hand edits under Packages/CityCore/Sources/CityCore/Generated/
#   post — validates the packs after a .yaml edit under Packages/CityCore/GameData/
#
# It runs for every agent edit in the repository, so it decides on the
# edited file's path alone and does nothing else for any other file:
# `pre` never builds, and `post` builds the generator only for pack edits.
# It fails open: if the path can't be read, or the generator can't be
# built or run, the edit goes through. Exit 2 blocks the edit (pre) or
# reports stderr back to the agent (post).
#
# Not covered: the Bash tool isn't hooked, so `sed -i` or a redirect into
# Generated/ bypasses `pre`. The pre-commit `gamedata-check` catches that
# drift before it is committed.
set -uo pipefail

generated=Packages/CityCore/Sources/CityCore/Generated/
data=Packages/CityCore/GameData/

phase=${1:-}
input=$(cat) || exit 0

# tool_input.file_path, or nothing when the input has none.
edited_path() {
    if command -v plutil >/dev/null 2>&1; then
        plutil -extract tool_input.file_path raw -o - - 2>/dev/null
    else
        python3 -c 'import json, sys; print(json.load(sys.stdin)["tool_input"]["file_path"], end="")' 2>/dev/null
    fi
}
path=$(printf '%s' "$input" | edited_path) || exit 0

case "$phase:$path" in
    pre:*/"$generated"* | pre:"$generated"*)
        echo "$path is generated from the content packs; don't edit it by hand." \
            "Change the pack under $data instead, then run \`make gamedata\` to regenerate." >&2
        exit 2
        ;;
    post:*/"$data"*.yaml) root=${path%%/"$data"*} ;;
    post:"$data"*.yaml) root=. ;;
    *) exit 0 ;;
esac

# Build and validate in the checkout that holds the edited pack, so an
# edit in another worktree is checked against that worktree's generator.
cd "$root" 2>/dev/null || exit 0
swift=(swift)
if command -v xcrun >/dev/null 2>&1; then swift=(xcrun swift); fi
# Debug, like `make gamedata`, so both share one incremental build.
"${swift[@]}" build -q --package-path Packages/GameDataGen --product gamedata-gen >/dev/null 2>&1 || exit 0
bin=Packages/GameDataGen/.build/debug/gamedata-gen
[ -x "$bin" ] || exit 0

printf '%s' "$input" | "$bin" hook post
[ $? -eq 2 ] && exit 2
exit 0
