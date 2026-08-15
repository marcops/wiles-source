#!/usr/bin/env bash
# Builds Wiles.app in debug mode into .build/ui-test-app/Wiles.app. This exists only to give
# WilesUITests a real .app to launch — SPM's `swift build` alone produces a bare Mach-O
# executable, not an app bundle, and XCUIApplication needs a real bundle (Info.plist +
# CFBundleIdentifier) to launch. Mirrors the release build's app-bundle packaging (see
# .github/workflows/release.yml), minus the release-only signing/zip/dmg steps.
#
# Usage: scripts/build_debug_app.sh
# Invoked as a Run Script build phase by the XcodeGen-generated Wiles.xcodeproj's "Wiles" app
# target (see project.yml) — xcodebuild expects the product to land at $TARGET_BUILD_DIR/Wiles.app.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# $TARGET_BUILD_DIR/Wiles.app is created by Xcode's own app-packaging build phases (product type
# "application" + GENERATE_INFOPLIST_FILE) before this script phase runs — this script only needs
# to drop the real binary + resources into it. Xcode's own Info.plist processing and code-sign
# phases run after this one and finish the job.
APP_DIR="${TARGET_BUILD_DIR:-$ROOT_DIR/.build/ui-test-app}/Wiles.app"

echo "==> Building Wiles (debug)..."
swift build

BIN_PATH=""
if [[ -f ".build/arm64-apple-macosx/debug/Wiles" ]]; then
  BIN_PATH=".build/arm64-apple-macosx/debug/Wiles"
elif [[ -f ".build/debug/Wiles" ]]; then
  BIN_PATH=".build/debug/Wiles"
else
  echo "error: debug binary not found" >&2
  exit 1
fi

mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/Wiles"

RES_BUNDLE="$(dirname "$BIN_PATH")/Wiles_Wiles.bundle"
if [[ -d "$RES_BUNDLE" ]]; then
  rm -rf "$APP_DIR/Contents/Resources/Wiles_Wiles.bundle"
  cp -r "$RES_BUNDLE" "$APP_DIR/Contents/Resources/"
else
  echo "error: Wiles_Wiles.bundle missing next to debug binary" >&2
  exit 1
fi

echo "==> Copied Wiles binary + resources into $APP_DIR"
