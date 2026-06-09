#!/usr/bin/env bash
#
# Builds, signs (Developer ID + hardened runtime), notarizes, staples, and zips
# Prismatic.app for distribution — so users don't need --no-quarantine.
#
# One-time setup (see README → Releasing):
#   1. A "Developer ID Application" certificate installed in your keychain.
#   2. A notarytool credential profile named "prismatic":
#        xcrun notarytool store-credentials prismatic \
#          --apple-id "you@example.com" --team-id CKWYP7CT7C --password <app-specific-password>
#      (or use an App Store Connect API key — see notarytool docs.)
#
# Usage:  scripts/notarize.sh
#   Override the profile with: NOTARY_PROFILE=myprofile scripts/notarize.sh
#   If Xcode isn't found: DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/notarize.sh

set -euo pipefail
cd "$(dirname "$0")/.."

SCHEME="Prismatic"
APP="Prismatic.app"
NOTARY_PROFILE="${NOTARY_PROFILE:-prismatic}"
BUILD="$(pwd)/build"
ARCHIVE="$BUILD/Prismatic.xcarchive"
EXPORT_DIR="$BUILD/export"
ZIP="$(pwd)/Prismatic.zip"

echo "› Archiving (Release, hardened runtime)…"
xcodebuild -project prisma-led-macos.xcodeproj -scheme "$SCHEME" -configuration Release \
  -archivePath "$ARCHIVE" archive | tail -2

echo "› Exporting Developer ID app…"
rm -rf "$EXPORT_DIR"
xcodebuild -exportArchive -archivePath "$ARCHIVE" \
  -exportOptionsPlist scripts/ExportOptions.plist -exportPath "$EXPORT_DIR" | tail -2

APP_PATH="$EXPORT_DIR/$APP"
[ -d "$APP_PATH" ] || { echo "✗ Export failed: $APP_PATH not found" >&2; exit 1; }

echo "› Zipping for notarization…"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP_PATH" "$ZIP"

echo "› Submitting to Apple notary service (a few minutes)…"
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait

echo "› Stapling the ticket onto the app…"
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"

echo "› Re-zipping the stapled app for release…"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP_PATH" "$ZIP"

echo
echo "✓ Notarized & stapled → $ZIP"
echo "  Gatekeeper assessment:"
spctl --assess --type execute -vvv "$APP_PATH" 2>&1 | sed 's/^/    /' || true
echo "  sha256 (for the Homebrew cask):"
shasum -a 256 "$ZIP"
echo
echo "Next: upload Prismatic.zip to a GitHub release tagged v<version>,"
echo "      then update version + sha256 in Casks/prismatic.rb (and your tap)."
