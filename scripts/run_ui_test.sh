#!/usr/bin/env bash
# Build + run the AXUIElement-based full-feature UI walkthrough (UITestRunner/).
#
# The runner is a standalone Swift executable that drives a debug Wiles.app from the outside via
# the macOS Accessibility API — no XCUITest, no xcodebuild. This script:
#   1. kills any Wiles instance or previous runner still alive (a leftover breaks the next launch),
#   2. builds the debug Wiles binary and assembles a launchable .build/uitest/Wiles.app,
#   3. builds the runner,
#   4. runs it (the runner self-checks Accessibility trust and prints how to grant it).
# UI tests carry no lint step.
#
# Usage: scripts/run_ui_test.sh [--no-build]

set -uo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP_BUNDLE="$ROOT_DIR/.build/uitest/Wiles.app"
RUNNER_BIN="$ROOT_DIR/UITestRunner/.build/debug/uitestrunner"

echo "==> ensure nothing from a previous run is alive"
pkill -9 -f 'uitestrunner'                          2>/dev/null || true
pkill -9 -f 'xcodebuild.*(test|WilesUITests)'       2>/dev/null || true
pkill -9 -f 'XCTRunner|WilesUITests-Runner'         2>/dev/null || true
pkill -9 -f '\.build/uitest/Wiles\.app/Contents/MacOS/Wiles' 2>/dev/null || true
pkill -9 -f 'Wiles\.app/Contents/MacOS/Wiles .*--ui-testing' 2>/dev/null || true
sleep 2
LEFT="$(pgrep -lf 'uitestrunner|\.build/uitest/Wiles\.app/Contents/MacOS/Wiles' | grep -v run_ui_test || true)"
if [[ -n "$LEFT" ]]; then
  echo "    still alive after SIGKILL:"; echo "$LEFT" | sed 's/^/      /'
else
  echo "    clean"
fi

if [[ "${1:-}" != "--no-build" ]]; then
  echo "==> build debug Wiles binary"
  swift build 2>&1 | grep -E 'error:|warning:|Compiling|Build complete' | tail -5 || true

  BIN=".build/arm64-apple-macosx/debug/Wiles"
  [[ -f "$BIN" ]] || BIN=".build/debug/Wiles"
  if [[ ! -f "$BIN" ]]; then echo "==> debug Wiles binary not found"; exit 1; fi
  RES_BUNDLE="$(dirname "$BIN")/Wiles_Wiles.bundle"

  echo "==> assemble $APP_BUNDLE"
  rm -rf "$APP_BUNDLE"
  mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
  sed 's/__VERSION__/0.0.0-uitest/g' Info.plist > "$APP_BUNDLE/Contents/Info.plist"
  cp "$BIN" "$APP_BUNDLE/Contents/MacOS/Wiles"
  cp -R "$RES_BUNDLE" "$APP_BUNDLE/Contents/Resources/"
  [[ -f Wiles.app/Contents/Resources/AppIcon.icns ]] && \
    cp Wiles.app/Contents/Resources/AppIcon.icns "$APP_BUNDLE/Contents/Resources/"
  codesign -f -s - --identifier com.marco.wiles "$APP_BUNDLE" >/dev/null 2>&1 || true

  echo "==> build runner"
  swift build --package-path UITestRunner 2>&1 | grep -E 'error:|warning:|Compiling|Build complete' | tail -5 || true
fi

if [[ ! -x "$RUNNER_BIN" ]]; then echo "==> runner binary missing ($RUNNER_BIN)"; exit 1; fi

echo "==> run walkthrough"
echo "------------------------------------------------------------"
"$RUNNER_BIN" --app "$APP_BUNDLE"
STATUS=$?
echo "------------------------------------------------------------"
echo "exit: $STATUS"
exit $STATUS
