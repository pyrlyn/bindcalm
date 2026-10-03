#!/bin/bash
# Wraps the SwiftPM executable into a runnable, ad-hoc signed .app bundle.
# Usage: scripts/bundle.sh [release|debug]   → dist/ShortcutClash.app
set -euo pipefail

cd "$(dirname "$0")/.."
CONFIG="${1:-release}"
APP_NAME="ShortcutClash"
APP="dist/${APP_NAME}.app"

swift build -c "$CONFIG" --arch arm64
BIN_DIR="$(swift build -c "$CONFIG" --arch arm64 --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# Ad-hoc identity: TCC keys grants to the code hash, so every rebuild looks like a new app to
# Accessibility / Input Monitoring. A stable Developer ID signature avoids that.
codesign --force --sign - --timestamp=none "$APP"
codesign --verify --strict "$APP"
echo "Built $APP"
