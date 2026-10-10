#!/usr/bin/env bash
# scripts/check-ios-icon-opaque.sh
#
# Verifies that the iOS marketing icon has no alpha channel. App Store
# Connect rejects an upload whose 1024px icon has one (error 90717),
# even when every pixel is opaque, and only says so at upload time.
#
# Exit codes:
#   0 — the icon has no alpha channel
#   1 — the icon is missing, not a 1024px image, or has an alpha channel

set -euo pipefail

ICON="${1:-Apps/CitybuilderiOS/Assets.xcassets/AppIcon.appiconset/icon-1024.png}"

if [[ ! -f "$ICON" ]]; then
    echo "check-ios-icon-opaque: $ICON not found" >&2
    exit 1
fi

# sips exits 0 and reports "hasAlpha: no" for a file it cannot decode, so
# an unreadable icon shows up only as a missing pixel width.
info=$(sips -g pixelWidth -g hasAlpha "$ICON")

if ! grep -q "pixelWidth: 1024" <<< "$info"; then
    echo "check-ios-icon-opaque: $ICON is not a readable 1024px image" >&2
    exit 1
fi

if grep -q "hasAlpha: yes" <<< "$info"; then
    echo "ERROR: $ICON has an alpha channel; App Store Connect rejects it." >&2
    echo "       Regenerate it with 'xcrun swift scripts/generate-app-icon.swift'." >&2
    exit 1
fi

exit 0
