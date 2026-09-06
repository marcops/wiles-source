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
# Usage: scripts/run_ui_test.sh [--no-build] [--plan] [--screenshots]
#   --plan         run the deeper UI_TEST_PLAN.md suite instead of the FEATURES.md feature tour.
#   --screenshots  stage every FEATURES.md feature and capture <slug>-{light,dark}.png into
#                  wiles-public/docs/screenshots/features/ instead of running the assert walkthrough.
#   --no-build     skip the Wiles + runner rebuild and reuse the last one (for a second-pass mode).

set -uo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

MODE_ARGS=()
NO_BUILD=0
for arg in "$@"; do
  case "$arg" in
    --no-build) NO_BUILD=1 ;;
    --screenshots) MODE_ARGS+=(--screenshots) ;;
    --plan) MODE_ARGS+=(--plan) ;;
    --fast) MODE_ARGS+=(--fast) ;;
    --slow) MODE_ARGS+=(--slow) ;;
    --scale) MODE_ARGS+=(--scale) ;;
    [0-9]*) MODE_ARGS+=("$arg") ;;
  esac
done

APP_BUNDLE="$ROOT_DIR/.build/uitest/Wiles.app"
RUNNER_BIN="$ROOT_DIR/UITestRunner/.build/debug/uitestrunner"
# Isolated bundle id → the run uses its own UserDefaults domain, never the user's real Wiles prefs.
UITEST_BUNDLE_ID="com.marco.wiles.uitest"

echo "==> ensure nothing from a previous run is alive"
pkill -9 -f 'uitestrunner'                          2>/dev/null || true
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
# Wipe every trace of a previous run — the isolated defaults domain (collapsed sections,
# non-default theme/view-mode, stale window frames), its saved-state bundle, and any cached
# prefs — so a run always starts from a clean app. Then seed only what every run needs.
defaults delete "$UITEST_BUNDLE_ID" 2>/dev/null || true
rm -rf "$HOME/Library/Saved Application State/${UITEST_BUNDLE_ID}.savedState" 2>/dev/null || true
rm -rf "$HOME/Library/Caches/${UITEST_BUNDLE_ID}" 2>/dev/null || true
rm -f  "$HOME/Library/Preferences/${UITEST_BUNDLE_ID}.plist" 2>/dev/null || true
# cfprefsd can hold the old values in memory — force it to drop them for this domain.
/usr/bin/killall -u "$USER" cfprefsd 2>/dev/null || true
defaults read "$UITEST_BUNDLE_ID" >/dev/null 2>&1 && defaults delete "$UITEST_BUNDLE_ID" 2>/dev/null || true
# Seed English so the app is English from first paint. Every step past the first assumes English
# menu/label text — a flaky Settings interaction on step 1 must not cascade into 40 false failures.
# The first walkthrough step still exercises Settings ▸ General ▸ Language (and F1's live re-localize).
defaults write "$UITEST_BUNDLE_ID" wiles_appLanguage en 2>/dev/null || true
defaults write "$UITEST_BUNDLE_ID" wiles_skipDeleteConfirmation -bool YES 2>/dev/null || true

if [[ ${#MODE_ARGS[@]} -gt 0 ]]; then
  echo "==> run: ${MODE_ARGS[*]}"
else
  echo "==> run walkthrough"
fi
echo "------------------------------------------------------------"
# Hard overall cap so a wedged interaction can't hang forever (macOS has no `timeout`).
CAP_SECONDS=1800
"$RUNNER_BIN" --app "$APP_BUNDLE" ${MODE_ARGS[@]+"${MODE_ARGS[@]}"} &
RUNNER_PID=$!
( sleep "$CAP_SECONDS"; kill -9 "$RUNNER_PID" 2>/dev/null && echo "    (killed: exceeded ${CAP_SECONDS}s cap)" ) &
WATCHDOG_PID=$!
wait "$RUNNER_PID"
STATUS=$?
kill "$WATCHDOG_PID" 2>/dev/null || true
echo "------------------------------------------------------------"
echo "exit: $STATUS"
exit $STATUS
