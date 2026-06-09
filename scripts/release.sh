#!/usr/bin/env bash
#
# Builds a Release Prismatic.app, zips it, and prints the sha256 for the Homebrew cask.
#
# Usage:  scripts/release.sh
# If xcodebuild can't find Xcode, set DEVELOPER_DIR, e.g.:
#   DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/release.sh

set -euo pipefail

cd "$(dirname "$0")/.."

SCHEME="Prismatic"
APP="Prismatic.app"
BUILD_DIR="$(pwd)/build"
ZIP="$(pwd)/Prismatic.zip"

echo "› Building Release…"
xcodebuild \
  -project prisma-led-macos.xcodeproj \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  build | tail -3

APP_PATH="$BUILD_DIR/Build/Products/Release/$APP"
if [ ! -d "$APP_PATH" ]; then
  echo "✗ Build product not found at $APP_PATH" >&2
  exit 1
fi

echo "› Zipping (ditto, preserves code signature)…"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP_PATH" "$ZIP"

echo
echo "✓ Created $ZIP"
echo "  sha256:"
shasum -a 256 "$ZIP"
echo
echo "Next:"
echo "  1. Create a GitHub release tagged v<version> and upload Prismatic.zip"
echo "  2. Update version + sha256 in Casks/prismatic.rb (and your tap)"
echo
echo "Tip: for a public release, sign + notarize with a Developer ID so users"
echo "     don't need --no-quarantine:"
echo "       codesign --deep --options runtime --sign \"Developer ID Application: …\" \"$APP_PATH\""
echo "       xcrun notarytool submit \"$ZIP\" --keychain-profile <profile> --wait"
echo "       xcrun stapler staple \"$APP_PATH\"  (then re-zip)"
