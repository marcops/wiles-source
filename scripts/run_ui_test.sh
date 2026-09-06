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
# Usage: scripts/run_ui_test.sh [--no-build] [--screenshots]
#   --screenshots  stage every FEATURES.md feature and capture <slug>-{light,dark}.png into
#                  wiles-public/docs/screenshots/features/ instead of running the assert walkthrough.

set -uo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

MODE_ARGS=()
NO_BUILD=0
for arg in "$@"; do
  case "$arg" in
    --no-build) NO_BUILD=1 ;;
    --screenshots) MODE_ARGS+=(--screenshots) ;;
  esac
done

APP_BUNDLE="$ROOT_DIR/.build/uitest/Wiles.app"
RUNNER_BIN="$ROOT_DIR/UITestRunner/.build/debug/uitestrunner"
# Isolated bundle id → the run uses its own UserDefaults domain, never the user's real Wiles prefs.
UITEST_BUNDLE_ID="com.marco.wiles.uitest"

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

if [[ "$NO_BUILD" -eq 0 ]]; then
  echo "==> build debug Wiles binary"
  swift build 2>&1 | grep -E 'error:|warning:|Compiling|Build complete' | tail -5 || true

  BIN=".build/arm64-apple-macosx/debug/Wiles"
  [[ -f "$BIN" ]] || BIN=".build/debug/Wiles"
  if [[ ! -f "$BIN" ]]; then echo "==> debug Wiles binary not found"; exit 1; fi
  RES_BUNDLE="$(dirname "$BIN")/Wiles_Wiles.bundle"

  echo "==> assemble $APP_BUNDLE"
  rm -rf "$APP_BUNDLE"
  mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
  sed -e 's/__VERSION__/0.0.0-uitest/g' \
      -e "s#<string>com.marco.wiles</string>#<string>${UITEST_BUNDLE_ID}</string>#" \
      Info.plist > "$APP_BUNDLE/Contents/Info.plist"
  cp "$BIN" "$APP_BUNDLE/Contents/MacOS/Wiles"
  cp -R "$RES_BUNDLE" "$APP_BUNDLE/Contents/Resources/"
  [[ -f Wiles.app/Contents/Resources/AppIcon.icns ]] && \
    cp Wiles.app/Contents/Resources/AppIcon.icns "$APP_BUNDLE/Contents/Resources/"
  codesign -f -s - --identifier com.marco.wiles "$APP_BUNDLE" >/dev/null 2>&1 || true

  echo "==> build runner"
  swift build --package-path UITestRunner 2>&1 | grep -E 'error:|warning:|Compiling|Build complete' | tail -5 || true
fi

if [[ ! -x "$RUNNER_BIN" ]]; then echo "==> runner binary missing ($RUNNER_BIN)"; exit 1; fi

echo "==> deterministic run state ($UITEST_BUNDLE_ID domain)"
if [[ ${#MODE_ARGS[@]} -gt 0 && " ${MODE_ARGS[*]} " == *" --screenshots "* ]]; then
  # Screenshots want a cleanly English app from first paint (a live language switch leaves the
  # footer free-space string stale — see the runner README). The walkthrough still exercises the
  # real Settings language switch as its first step.
  defaults write "$UITEST_BUNDLE_ID" wiles_appLanguage en 2>/dev/null || true
else
  defaults delete "$UITEST_BUNDLE_ID" wiles_appLanguage 2>/dev/null || true
fi
defaults write "$UITEST_BUNDLE_ID" wiles_skipDeleteConfirmation -bool YES 2>/dev/null || true
defaults delete "$UITEST_BUNDLE_ID" wiles_lastOpenedFolder 2>/dev/null || true
for i in 1 2 3 4 5; do
  defaults delete "$UITEST_BUNDLE_ID" "NSWindow Frame main-AppWindow-$i" 2>/dev/null || true
  defaults delete "$UITEST_BUNDLE_ID" "NSWindow Frame WilesMainWindow-$i" 2>/dev/null || true
done

if [[ ${#MODE_ARGS[@]} -gt 0 ]]; then
  echo "==> run: ${MODE_ARGS[*]}"
else
  echo "==> run walkthrough"
fi
echo "------------------------------------------------------------"
"$RUNNER_BIN" --app "$APP_BUNDLE" ${MODE_ARGS[@]+"${MODE_ARGS[@]}"}
STATUS=$?
echo "------------------------------------------------------------"
echo "exit: $STATUS"
exit $STATUS
