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
    --all) MODE_ARGS+=(--all) ;;
    --chunked) MODE_ARGS+=(--chunked) ;;
    --fast) MODE_ARGS+=(--fast) ;;
    --slow) MODE_ARGS+=(--slow) ;;
    --scale|--only|--out) MODE_ARGS+=("$arg") ;;
    *) [[ ${#MODE_ARGS[@]} -gt 0 ]] && MODE_ARGS+=("$arg") ;;
  esac
done

APP_BUNDLE="$ROOT_DIR/.build/uitest/Wiles.app"
RUNNER_BIN="$ROOT_DIR/UITestRunner/.build/debug/uitestrunner"
# Isolated bundle id → the run uses its own UserDefaults domain, never the user's real Wiles prefs.
UITEST_BUNDLE_ID="com.marco.wiles.uitest"

# Kill the test runner, the isolated test app, and Quick Look / Preview it spawned.
teardown() {
  pkill -9 -f 'uitestrunner'                                    2>/dev/null || true
  pkill -9 -f '\.build/uitest/Wiles\.app/Contents/MacOS/Wiles'  2>/dev/null || true
  pkill -9 -f 'Wiles\.app/Contents/MacOS/Wiles .*--ui-testing'  2>/dev/null || true
  pkill -9 -x 'QuickLookUIService'                              2>/dev/null || true
  pkill -9 -f 'qlmanage'                                        2>/dev/null || true
  # Preview only if it's showing a file from our throwaway workspace.
  if pgrep -qx Preview && lsof -p "$(pgrep -x Preview)" 2>/dev/null | grep -q 'WilesAXUITest-'; then
    pkill -9 -x Preview 2>/dev/null || true
  fi
}
trap teardown EXIT

echo "==> ensure nothing from a previous run is alive"
teardown
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
  codesign -f -s - --identifier com.marco.wiles.uitest "$APP_BUNDLE" >/dev/null 2>&1 || true

  echo "==> build runner"
  swift build --package-path UITestRunner 2>&1 | grep -E 'error:|warning:|Compiling|Build complete' | tail -5 || true
fi

if [[ ! -x "$RUNNER_BIN" ]]; then echo "==> runner binary missing ($RUNNER_BIN)"; exit 1; fi

echo "==> deterministic run state ($UITEST_BUNDLE_ID domain)"
# Every run starts from zero. Don't touch cfprefsd — killing it mid-launch breaks the app's defaults.
defaults delete "$UITEST_BUNDLE_ID" 2>/dev/null || true
rm -rf "$HOME/Library/Saved Application State/${UITEST_BUNDLE_ID}.savedState" 2>/dev/null || true
# Seed English so the app paints English from the start; step 1 still exercises the language switch.
defaults write "$UITEST_BUNDLE_ID" wiles_appLanguage en 2>/dev/null || true
defaults write "$UITEST_BUNDLE_ID" wiles_skipDeleteConfirmation -bool YES 2>/dev/null || true
# Sections the walkthrough exercises that default to hidden.
defaults write "$UITEST_BUNDLE_ID" wiles_showDirectoryTree -bool YES 2>/dev/null || true
defaults write "$UITEST_BUNDLE_ID" wiles_showNetworkAndCloud -bool YES 2>/dev/null || true
defaults write "$UITEST_BUNDLE_ID" wiles_showTags -bool YES 2>/dev/null || true

# One runner invocation with a hard cap (macOS has no `timeout`). Each call is a fresh app launch.
run_once() {
  echo "------------------------------------------------------------"
  echo "==> run: $*"
  teardown; sleep 1
  local cap=420 pid waited=0
  "$RUNNER_BIN" --app "$APP_BUNDLE" "$@" & pid=$!
  # Poll instead of a backgrounded `sleep $cap` watchdog: killing that subshell only kills the
  # subshell wrapper, not the `sleep` running inside it — the sleep survives as an orphan holding
  # the pipe fd it inherited from `| tee` (--chunked mode), so tee never sees EOF and the whole
  # per-chunk pipeline stalls for up to $cap seconds even after the real run already finished.
  while kill -0 "$pid" 2>/dev/null; do
    sleep 1
    waited=$((waited + 1))
    if [[ "$waited" -ge "$cap" ]]; then
      kill -9 "$pid" 2>/dev/null
      echo "    (killed: exceeded ${cap}s cap)"
      break
    fi
  done
  wait "$pid" 2>/dev/null; local st=$?
  return $st
}

# --chunked: run the whole suite as several short, fresh-launch passes — the only way it survives
# on a machine where a long single launch gets throttled into uselessness.
if [[ " ${MODE_ARGS[*]+${MODE_ARGS[*]}} " == *" --chunked "* ]]; then
  FEAT_A="featSwitchToEnglish,featLaunchShell,featGridAndListViews,featDirectoryTree,featFavoritesAndPlaces,featSearch,featFileProperties,featSymbolicLinks,featCompressToZip,featUndoRedo,featBatchRename"
  FEAT_B="featImageConverter,featArchiveInspector,featDuplicateFinder,featIntegratedTerminal,featDiskUsageVisualizer,featConnectToServer,featAutoOrganization,featHTTPSharing,featTags,featSmartFolders,featAppearanceSettings"
  PLAN_A="featNewAndCloseWindow,featSidebarSectionHeaders,featSectionCollapsePersists,featHideShowSection,featDirectoryTreeDrillIn,featSmartFoldersSectionRenders,featPathBarNavigation,featBackForwardEnclosing,featNewFolderInlineRename,featNewFileInlineRename,featRenameUndoRedo,featCutPaste,featCopyPaste,featKeyboardSelectionNav,featSelectAllThenClear,featSortOrder"
  PLAN_B="featIconZoom,featQuickLook,featEmptyDirectory,featFooterTerminalButton,featTogglePreview,featSettingsTabs,featHelpSheet,featShortcutsHUD,featAboutSheet,featFeedbackSheet,featChmodInProperties,featArchiveExtract,featFileShredder,featCopyContent,featOpenWithSubmenu,featTagAssign,featClearAllTags,featCopyPath,featPDFMerge"
  PLAN_C="featDuplicateFinderScan,featCompressWithPassword,featSmartFolderRoundTrip,featHTTPServerRoundTrip,featNavigationModeGnome,featPreferencePersistenceSweep,featShiftClickRange,featCmdClickDeselectsOne,featClickEmptyAreaDeselects,featArrowPastLastRowStays,featRenameToExistingNameHandled,featRenameWithSlashSanitised,featNewFolderNameAutoIncrements,featSortByEachKeyReorders,featIconZoomClampsAtMinimum,featShowHiddenFilesToggle"
  PLAN_D="featSearchNoMatchThenClear,featPropertiesShortcut,featTrashShortcutThenUndo,featPathBarRejectsBadPath,featKeyboardHistoryNav,featPlacesEntryNavigates,featListColumnHeaderClickSorts,featCompactDensityToggle,featAutoHideSidebarToggle,featSearchScopeToggle,featSearchKindFilterToken,featSearchShortContentTermWarning,featQuickFilterImages,featStatusBarCountReflectsSelection,featPreviewPaneFollowsSelection,featSymlinkModalReopen,featAddRemoveFavorite,featTagFilterNavigates,featMoveCollisionSheet,featViewModeSwitcherExpandsOnHover,featTypeAheadRowSelection,featRenameMenuItem,featBatchRenameAppliesFindReplace,featFolderPropertiesFromBackground"
  AGG=/tmp/wiles_chunked.log; : > "$AGG"
  for spec in "-|$FEAT_A" "-|$FEAT_B" "--plan|$PLAN_A" "--plan|$PLAN_B" "--plan|$PLAN_C" "--plan|$PLAN_D"; do
    mode="${spec%%|*}"; only="${spec#*|}"
    if [[ "$mode" == "-" ]]; then run_once --only "$only" | tee -a "$AGG"
    else run_once --plan --only "$only" | tee -a "$AGG"; fi
  done
  echo "============================================================"
  awk '
    /^[0-9]+ checks · [0-9]+ passed · [0-9]+ failed/ { c+=$1; p+=$4; f+=$7 }
    /^  ✗ \[/ { fails[++n]=$0 }
    END {
      print c " checks · " p " passed · " f " failed  (chunked)"
      if (n) { print "\nFailures:"; for (i=1;i<=n;i++) print fails[i] }
    }' "$AGG"
  echo "============================================================"
  grep -q '^  ✗ \[' "$AGG" && exit 1 || exit 0
fi

STATUS=0
run_once ${MODE_ARGS[@]+"${MODE_ARGS[@]}"} || STATUS=$?
echo "------------------------------------------------------------"
echo "exit: $STATUS"
exit $STATUS
