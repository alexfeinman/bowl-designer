#!/usr/bin/env bash
# Build the macOS release and package it into a distributable .dmg.
#
# Usage:
#   tool/package_macos.sh                 # build + create dist/<App> <version>.dmg
#   tool/package_macos.sh --no-build      # package the existing Release build
#   CODESIGN_IDENTITY="Developer ID Application: Name (TEAMID)" tool/package_macos.sh
#
# No third-party tools required — uses `flutter`, `hdiutil`, and (optionally)
# `codesign`. The app is ad-hoc signed by the Flutter build; set CODESIGN_IDENTITY
# to sign with a Developer ID for distribution outside your own machine.
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="Segmented Bowl Designer"          # must match macOS PRODUCT_NAME
RELEASE_DIR="build/macos/Build/Products/Release"
APP="$RELEASE_DIR/$APP_NAME.app"
OUT_DIR="dist"

VERSION="$(grep -E '^version:' pubspec.yaml | sed -E 's/version:[[:space:]]*([0-9.]+).*/\1/')"
DMG="$OUT_DIR/$APP_NAME $VERSION.dmg"

if [[ "${1:-}" != "--no-build" ]]; then
  echo "▶ flutter build macos --release"
  flutter build macos --release
fi

[[ -d "$APP" ]] || { echo "✗ Not found: $APP  (build first, or check PRODUCT_NAME)" >&2; exit 1; }

if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
  echo "▶ Codesigning with: $CODESIGN_IDENTITY"
  codesign --deep --force --options runtime --sign "$CODESIGN_IDENTITY" "$APP"
  codesign --verify --deep --strict "$APP" && echo "✔ signature valid"
else
  echo "• No CODESIGN_IDENTITY set — using the build's ad-hoc signature."
  echo "  (Gatekeeper will warn on other Macs; right-click → Open, or sign + notarize.)"
fi

mkdir -p "$OUT_DIR"
rm -f "$DMG"

# Stage a clean tree: the app + an /Applications drop target.
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

echo "▶ hdiutil create → $DMG"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGE" \
  -fs HFS+ \
  -format UDZO -imagekey zlib-level=9 \
  -ov "$DMG" >/dev/null

SIZE="$(du -h "$DMG" | cut -f1)"
echo "✔ Created $DMG ($SIZE)"
echo "  Drag-install: open the .dmg and drop the app onto Applications."
