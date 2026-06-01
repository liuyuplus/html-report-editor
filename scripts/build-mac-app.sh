#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="HTML报告编辑器.app"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME"
CONTENTS_DIR="$APP_DIR/Contents"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
MACOS_DIR="$CONTENTS_DIR/MacOS"

rm -rf "$APP_DIR"
mkdir -p "$RESOURCES_DIR" "$MACOS_DIR"

swiftc "$ROOT_DIR/mac/HTMLReportLiveEditor.swift" \
  -o "$MACOS_DIR/HTMLReportLiveEditor" \
  -framework Cocoa \
  -framework WebKit

cp "$ROOT_DIR/mac/Info.plist" "$CONTENTS_DIR/Info.plist"
printf 'APPL????' > "$CONTENTS_DIR/PkgInfo"

cp "$ROOT_DIR/src/html-report-live-editor.html" "$RESOURCES_DIR/html-report-live-editor.html"
cp "$ROOT_DIR/src/pm-issue-alignment-template.js" "$RESOURCES_DIR/pm-issue-alignment-template.js"
cp "$ROOT_DIR/assets/AppIcon-preview.png" "$RESOURCES_DIR/AppIcon-preview.png"
cp "$ROOT_DIR/assets/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

codesign --force --deep --sign - "$APP_DIR"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"

echo "Built $APP_DIR"
