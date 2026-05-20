#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="RMetronome"
EXECUTABLE_NAME="RMetronome"
PRODUCT_NAME="r-metronome-app"
BUNDLE_ID="com.randan.r-metronome"
ASSET_CATALOG="$ROOT_DIR/Sources/RMetronomeApp/Resources/Assets.xcassets"
ICON_COMPOSER_FILE="$ROOT_DIR/Sources/RMetronomeApp/Resources/AppIcon.icon"
PARTIAL_INFO_PLIST="$ROOT_DIR/.build/asset-info.plist"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
DMG_PATH="$DIST_DIR/$APP_NAME.dmg"
DMG_ROOT_DIR="$DIST_DIR/dmg-root"

cd "$ROOT_DIR"

export XDG_CACHE_HOME="$ROOT_DIR/.build/cache"
export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/clang-module-cache"
mkdir -p "$XDG_CACHE_HOME" "$CLANG_MODULE_CACHE_PATH"

BINARY_DIR="$(swift build -c release --show-bin-path)"
swift build -c release --product "$PRODUCT_NAME"

BINARY_PATH="$BINARY_DIR/$PRODUCT_NAME"

if [[ -z "${BINARY_PATH:-}" || ! -x "$BINARY_PATH" ]]; then
    echo "Release binary not found for $PRODUCT_NAME" >&2
    exit 1
fi

rm -rf "$APP_DIR" "$DMG_PATH" "$DMG_ROOT_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BINARY_PATH" "$MACOS_DIR/$EXECUTABLE_NAME"
chmod 755 "$MACOS_DIR/$EXECUTABLE_NAME"

compile_asset_catalog() {
    xcrun actool "$ASSET_CATALOG" \
        --compile "$RESOURCES_DIR" \
        --platform macosx \
        --target-device mac \
        --minimum-deployment-target 14.0 \
        --app-icon AppIcon \
        --output-partial-info-plist "$PARTIAL_INFO_PLIST"
}

compile_icon_composer_file() {
    xcrun actool "$ICON_COMPOSER_FILE" \
        --compile "$RESOURCES_DIR" \
        --platform macosx \
        --target-device mac \
        --minimum-deployment-target 14.0 \
        --app-icon AppIcon \
        --include-all-app-icons \
        --output-partial-info-plist "$PARTIAL_INFO_PLIST"
}

if [[ -e "$ICON_COMPOSER_FILE" ]]; then
    if ! compile_icon_composer_file; then
        echo "error: failed to compile $ICON_COMPOSER_FILE." >&2
        echo "Open and re-save the Icon Composer file, then run make dmg again." >&2
        exit 1
    fi
else
    echo "warning: $ICON_COMPOSER_FILE not found; building static PNG app icon fallback only." >&2
    compile_asset_catalog
fi

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
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
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

mkdir -p "$DMG_ROOT_DIR"
cp -R "$APP_DIR" "$DMG_ROOT_DIR/$APP_NAME.app"
ln -s /Applications "$DMG_ROOT_DIR/Applications"

hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_ROOT_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

echo "$DMG_PATH"
