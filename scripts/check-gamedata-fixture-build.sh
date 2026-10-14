#!/usr/bin/env bash
# Proves that content added in a pack compiles without Swift edits
# (game-data-codegen design D11). Copies the packages to a scratch
# directory, adds Packages/GameDataGen/Tests/Fixtures/fixture-pack.yaml
# to the manifest, regenerates CityCore's catalogs there and builds the
# packages that read them; CityCore builds as their dependency. Only
# the generator's own build directory in the working tree is written to.
#
# Usage: scripts/check-gamedata-fixture-build.sh
# Env:   SWIFT (default `xcrun swift`), KEEP_SCRATCH=1 to keep the copy.
set -euo pipefail

SWIFT=${SWIFT:-xcrun swift}
root=$(cd "$(dirname "$0")/.." && pwd)
scratch=$(mktemp -d "${TMPDIR:-/tmp}/gamedata-fixture.XXXXXX")
if [ "${KEEP_SCRATCH:-0}" = "1" ]; then
    echo "scratch copy: $scratch"
else
    trap 'rm -rf "$scratch"' EXIT
fi

for package in CityCore CityUI CityRender2D; do
    rsync -a --exclude .build --exclude .swiftpm "$root/Packages/$package" "$scratch/"
done
data="$scratch/CityCore/GameData"
cp "$root/Packages/GameDataGen/Tests/Fixtures/fixture-pack.yaml" "$data/packs/fixture.yaml"
printf '  - fixture\n' >> "$data/index.yaml"

$SWIFT run -q --package-path "$root/Packages/GameDataGen" gamedata-gen generate \
    --data "$data" --out "$scratch/CityCore/Sources/CityCore/Generated"

for package in CityUI CityRender2D; do
    echo "==> swift build $package with the fixture pack"
    $SWIFT build --package-path "$scratch/$package"
done
echo "fixture pack builds without Swift edits"
