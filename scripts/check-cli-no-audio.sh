#!/usr/bin/env bash
# scripts/check-cli-no-audio.sh
#
# Ensures the citybuilder-cli target does not import any audio framework so
# the headless runner stays Foundation-only and continues to run in CI
# contexts without loading AVFoundation. Per spec `audio-playback`
# (scenario "CLI does not link audio") and design D11.
#
# Approach: static scan of CLI source files for `import AVFoundation` or
# `import CityAudio`. This is pre-link validation — it catches the mistake
# at commit time rather than waiting for an otool inspection of the built
# binary. The otool variant can be added later when a CityAudio package
# exists and we want defense-in-depth.
#
# Exit codes:
#   0 — no forbidden imports
#   1 — at least one forbidden import found

set -euo pipefail

CLI_DIR="CLI/citybuilder-cli"
FORBIDDEN_PATTERN='^import (AVFoundation|CityAudio)\b'

if [[ ! -d "$CLI_DIR" ]]; then
    echo "check-cli-no-audio: $CLI_DIR not found — run from repo root" >&2
    exit 1
fi

if grep -REn "$FORBIDDEN_PATTERN" "$CLI_DIR" 2>/dev/null; then
    echo >&2
    echo "ERROR: citybuilder-cli must not import an audio framework." >&2
    echo "       Audio playback is an app-shell concern; the CLI stays headless." >&2
    exit 1
fi

exit 0
