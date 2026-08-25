#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

swift build -c release

APP_DIR="$PROJECT_ROOT/dist/Agent Space.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$CONTENTS_DIR/Resources"
cp "$PROJECT_ROOT/.build/release/AgentSpace" "$MACOS_DIR/AgentSpace"

plutil -create xml1 "$CONTENTS_DIR/Info.plist"
plutil -insert CFBundleExecutable -string AgentSpace "$CONTENTS_DIR/Info.plist"
plutil -insert CFBundleIdentifier -string app.agentspace.macos "$CONTENTS_DIR/Info.plist"
plutil -insert CFBundleName -string "Agent Space" "$CONTENTS_DIR/Info.plist"
plutil -insert CFBundleDisplayName -string "Agent Space" "$CONTENTS_DIR/Info.plist"
plutil -insert CFBundlePackageType -string APPL "$CONTENTS_DIR/Info.plist"
plutil -insert CFBundleShortVersionString -string 0.1.0 "$CONTENTS_DIR/Info.plist"
plutil -insert CFBundleVersion -string 1 "$CONTENTS_DIR/Info.plist"
plutil -insert LSMinimumSystemVersion -string 14.0 "$CONTENTS_DIR/Info.plist"
plutil -insert NSHighResolutionCapable -bool true "$CONTENTS_DIR/Info.plist"

codesign --force --deep --sign - "$APP_DIR"
echo "$APP_DIR"
