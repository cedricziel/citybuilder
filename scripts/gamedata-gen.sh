#!/usr/bin/env bash
# Builds gamedata-gen, then runs it with the given arguments, e.g.
# `scripts/gamedata-gen.sh generate --check`. `make gamedata` and
# `make gamedata-check` (also the pre-commit and pre-push hook) use it.
#
# A resolve that was interrupted (a killed hook, a full disk) can leave
# the package's Yams clone under .build/repositories without the objects
# its refs name. Every later build in that checkout then fails to check
# out Yams, and the shared SwiftPM cache can be damaged the same way
# (issue #90). So when the build fails, this drops the package's
# dependency clones and retries once without the shared cache, cloning
# Yams from its remote. A failing check is not retried: only the build is.
#
# Env: SWIFT (default `xcrun swift`).
set -euo pipefail

cd "$(dirname "$0")/.."
read -r -a swift <<<"${SWIFT:-xcrun swift}"
package=Packages/GameDataGen

build() {
    "${swift[@]}" build -q --package-path "$package" --product gamedata-gen "$@"
}

if ! build; then
    echo "gamedata-gen: build failed; retrying once with fresh dependency clones and no shared SwiftPM cache" >&2
    rm -rf "$package/.build/repositories" "$package/.build/checkouts"
    build --disable-dependency-cache
fi
exec "$("${swift[@]}" build --package-path "$package" --show-bin-path)/gamedata-gen" "$@"
