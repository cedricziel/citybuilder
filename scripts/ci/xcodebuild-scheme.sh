#!/usr/bin/env bash
# Builds one scheme of Citybuilder.xcodeproj for CI into the DerivedData
# the build job's other schemes share, so packages the schemes have in
# common compile once.
#
#   scripts/ci/xcodebuild-scheme.sh <scheme> <destination>
#
# Env: DERIVED_DATA (default $RUNNER_TEMP/DerivedData)
set -euo pipefail

scheme=${1:?usage: xcodebuild-scheme.sh <scheme> <destination>}
destination=${2:?usage: xcodebuild-scheme.sh <scheme> <destination>}
derived_data=${DERIVED_DATA:-${RUNNER_TEMP:-${TMPDIR:-/tmp}}/DerivedData}

xcodebuild \
    -project Citybuilder.xcodeproj \
    -scheme "$scheme" \
    -destination "$destination" \
    -derivedDataPath "$derived_data" \
    -configuration Debug \
    CODE_SIGNING_ALLOWED=NO \
    COMPILER_INDEX_STORE_ENABLE=NO \
    build | xcbeautify --renderer github-actions
