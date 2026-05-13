#!/usr/bin/env bash
# scripts/check-ios-fullscreen-lock.sh
#
# Verifies that the iOS app's Info.plist declares `UIRequiresFullScreen
# = true` — the key that opts the iPad app out of Split View, Slide
# Over, and Stage Manager. Spec: `add-fullscreen-launch` /
# `platform-shells` Requirement: iPad fullscreen lock.
#
# Approach: read the generated Info.plist (xcodegen writes it from
# `project.yml`'s `info.properties` block) and grep for the key. The
# check runs after `make generate` so the file exists.
#
# Exit codes:
#   0 — UIRequiresFullScreen is present and set to true
#   1 — key missing or set to false

set -euo pipefail

PLIST="Apps/CitybuilderiOS/Info.plist"

if [[ ! -f "$PLIST" ]]; then
    echo "check-ios-fullscreen-lock: $PLIST not found — run 'make generate' first" >&2
    exit 1
fi

VALUE=$(/usr/libexec/PlistBuddy -c "Print :UIRequiresFullScreen" "$PLIST" 2>/dev/null || echo "missing")

if [[ "$VALUE" != "true" ]]; then
    echo "ERROR: $PLIST is missing UIRequiresFullScreen = true (got: $VALUE)" >&2
    echo "       Spec add-fullscreen-launch requires the iPad app to lock fullscreen." >&2
    exit 1
fi

exit 0
