#!/bin/bash
# Wraps the SwiftPM executable into a runnable, signed .app bundle.
# Usage: scripts/bundle.sh [release|debug]   → dist/Bindcalm.app
#
# BINDCALM_CODESIGN_IDENTITY, when set to a codesign identity such as
# "Developer ID Application: Name (TEAMID)", signs with that identity and a
# secure timestamp so TCC grants survive rebuilds. Unset, empty, or "-" falls
# back to an ad-hoc signature (grants are tied to the code hash).
set -euo pipefail

cd "$(dirname "$0")/.."
CONFIG="${1:-release}"
APP_NAME="Bindcalm"
APP="dist/${APP_NAME}.app"

swift build -c "$CONFIG" --arch arm64
BIN_DIR="$(swift build -c "$CONFIG" --arch arm64 --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$APP/Contents/Info.plist"
# Info.plist carries Xcode build-setting placeholders (the release build sets them from the
# workflow's version input); a SwiftPM bundle has no build settings, so fill them in here.
VERSION="${BINDCALM_VERSION:-0.1.0}"
plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP/Contents/Info.plist"
plutil -replace CFBundleVersion -string "${BINDCALM_BUILD:-1}" "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# Ad-hoc identity: TCC keys grants to the code hash, so every rebuild looks like a new app to
# Accessibility / Input Monitoring. A stable Developer ID signature avoids that.
IDENTITY="${BINDCALM_CODESIGN_IDENTITY:-}"
if [[ -z "$IDENTITY" || "$IDENTITY" == "-" ]]; then
  codesign --force --sign - --timestamp=none "$APP"
  echo "Signed $APP ad-hoc"
else
  codesign --force --sign "$IDENTITY" --timestamp "$APP"
  echo "Signed $APP with identity: $IDENTITY"
fi
codesign --verify --strict "$APP"
echo "Built $APP"
