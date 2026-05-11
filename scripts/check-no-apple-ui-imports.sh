#!/usr/bin/env bash
# Enforces design D1 + D13: CityCore is framework-free.
# It MUST NOT import any Apple UI framework. Only Foundation and Swift
# stdlib are permitted (Foundation is intentionally allowed for Codable,
# Date, RNG, Data, etc.; it carries no UI dependencies).
#
# Usage:
#   scripts/check-no-apple-ui-imports.sh
#
# Exits 0 if clean, 1 if any forbidden import is detected.
set -euo pipefail

CITYCORE_DIR="Packages/CityCore/Sources"
FORBIDDEN=(
  "UIKit"
  "AppKit"
  "SwiftUI"
  "SpriteKit"
  "SceneKit"
  "RealityKit"
  "Metal"
  "MetalKit"
  "GameplayKit"
  "GameController"
  "AVKit"
  "WebKit"
  "MapKit"
  "PhotosUI"
)

if [ ! -d "$CITYCORE_DIR" ]; then
  echo "check-no-apple-ui-imports: $CITYCORE_DIR not found"
  exit 1
fi

violations=0
for fw in "${FORBIDDEN[@]}"; do
  if grep -rnE "^[[:space:]]*(@testable[[:space:]]+)?import[[:space:]]+$fw([[:space:]]|$)" "$CITYCORE_DIR" 2>/dev/null; then
    echo "  ^ Forbidden Apple UI framework '$fw' imported in CityCore (design D1)."
    violations=$((violations + 1))
  fi
done

if [ "$violations" -gt 0 ]; then
  echo ""
  echo "CityCore must remain framework-free. Move UI-dependent code into" >&2
  echo "CityRender2D, CityRender3D, CityUI, or one of the app targets." >&2
  exit 1
fi

echo "check-no-apple-ui-imports: CityCore is clean ($(find "$CITYCORE_DIR" -name '*.swift' | wc -l | tr -d ' ') files scanned)"
