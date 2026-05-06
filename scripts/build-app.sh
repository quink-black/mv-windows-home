#!/usr/bin/env bash
set -euo pipefail

# Build MoveWindowsHome.app from the SwiftPM executable and ad-hoc sign it.
# Output: build/MoveWindowsHome.app

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR"

APP_NAME="MoveWindowsHome"
BUILD_DIR="build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RES_DIR="$APP_DIR/Contents/Resources"

echo "[1/4] swift build -c release"
swift build -c release

BIN_PATH=$(swift build -c release --show-bin-path)/$APP_NAME
if [ ! -f "$BIN_PATH" ]; then
    echo "Executable not found at $BIN_PATH" >&2
    exit 1
fi

echo "[2/4] Assembling $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RES_DIR"
cp "$BIN_PATH" "$MACOS_DIR/$APP_NAME"
cp scripts/Info.plist "$APP_DIR/Contents/Info.plist"

echo "[3/4] Ad-hoc signing"
codesign --force --deep --sign - "$APP_DIR"

echo "[4/4] Done: $APP_DIR"
