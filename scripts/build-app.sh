#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

swift build -c release

APP_DIR="$PROJECT_ROOT/dist/CleanMyAgent.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
ICON_SOURCE="$PROJECT_ROOT/Sources/AgentSpace/Resources/AppIcon/cleanmyagent-app-icon.png"
ICON_WORK_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/cleanmyagent-icon.XXXXXX")"
ICONSET_DIR="$ICON_WORK_ROOT/CleanMyAgent.iconset"

trap 'rm -rf "$ICON_WORK_ROOT"' EXIT

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$CONTENTS_DIR/Resources"
cp "$PROJECT_ROOT/.build/release/CleanMyAgent" "$MACOS_DIR/CleanMyAgent"
RESOURCE_BUNDLE="$PROJECT_ROOT/.build/release/CleanMyAgent_AgentSpace.bundle"
if [ ! -d "$RESOURCE_BUNDLE" ]; then
  RESOURCE_BUNDLE="$PROJECT_ROOT/.build/release/AgentSpace_AgentSpace.bundle"
fi
if [ -d "$RESOURCE_BUNDLE" ]; then
  ditto "$RESOURCE_BUNDLE" "$CONTENTS_DIR/Resources/CleanMyAgent_AgentSpace.bundle"
  ditto "$RESOURCE_BUNDLE" "$CONTENTS_DIR/Resources/AgentSpace_AgentSpace.bundle"
fi

mkdir -p "$ICONSET_DIR"
sips -z 16 16 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$ICONSET_DIR" -o "$CONTENTS_DIR/Resources/CleanMyAgent.icns"

plutil -create xml1 "$CONTENTS_DIR/Info.plist"
plutil -insert CFBundleExecutable -string CleanMyAgent "$CONTENTS_DIR/Info.plist"
plutil -insert CFBundleIdentifier -string com.cleanmyagent.macos "$CONTENTS_DIR/Info.plist"
plutil -insert CFBundleName -string CleanMyAgent "$CONTENTS_DIR/Info.plist"
plutil -insert CFBundleDisplayName -string CleanMyAgent "$CONTENTS_DIR/Info.plist"
plutil -insert CFBundleIconFile -string CleanMyAgent "$CONTENTS_DIR/Info.plist"
plutil -insert CFBundlePackageType -string APPL "$CONTENTS_DIR/Info.plist"
plutil -insert CFBundleShortVersionString -string 0.1.0 "$CONTENTS_DIR/Info.plist"
plutil -insert CFBundleVersion -string 1 "$CONTENTS_DIR/Info.plist"
plutil -insert LSMinimumSystemVersion -string 14.0 "$CONTENTS_DIR/Info.plist"
plutil -insert NSHighResolutionCapable -bool true "$CONTENTS_DIR/Info.plist"

codesign --force --deep --sign - "$APP_DIR"
echo "$APP_DIR"
