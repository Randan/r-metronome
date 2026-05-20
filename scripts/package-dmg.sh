#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="r-metronome"
EXECUTABLE_NAME="r-metronome"
PRODUCT_NAME="r-metronome-app"
BUNDLE_ID="com.randan.r-metronome"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
DMG_PATH="$DIST_DIR/$APP_NAME.dmg"

cd "$ROOT_DIR"

export XDG_CACHE_HOME="$ROOT_DIR/.build/cache"
export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/clang-module-cache"
mkdir -p "$XDG_CACHE_HOME" "$CLANG_MODULE_CACHE_PATH"

swift build -c release --product "$PRODUCT_NAME"

BINARY_PATH="$ROOT_DIR/.build/release/$PRODUCT_NAME"
if [[ ! -x "$BINARY_PATH" ]]; then
    BINARY_PATH="$(find "$ROOT_DIR/.build" -path "*/release/$PRODUCT_NAME" -type f -perm -111 | head -n 1)"
fi

if [[ -z "${BINARY_PATH:-}" || ! -x "$BINARY_PATH" ]]; then
    echo "Release binary not found for $PRODUCT_NAME" >&2
    exit 1
fi

rm -rf "$APP_DIR" "$DMG_PATH"
mkdir -p "$MACOS_DIR"

cp "$BINARY_PATH" "$MACOS_DIR/$EXECUTABLE_NAME"
chmod 755 "$MACOS_DIR/$EXECUTABLE_NAME"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$EXECUTABLE_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$APP_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

echo "$DMG_PATH"
