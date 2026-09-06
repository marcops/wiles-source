#!/usr/bin/env bash
# Runs every validation you'd otherwise do by hand before a release:
# build with zero warnings, tests, SwiftLint, SwiftFormat.
#
# Usage: scripts/validate.sh
# Exit code 0 = everything passed. Non-zero = something needs fixing.

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

FAILED=0
COVERAGE_PCT="(not measured)"
COVERAGE_LINE=""

VALIDATE_START=$SECONDS
STEP_START=$SECONDS
STEP_NAME=""

section() {
  if [[ -n "$STEP_NAME" ]]; then
    echo "(\"$STEP_NAME\" took $((SECONDS - STEP_START))s)"
  fi
  echo
  echo "==> $1"
  STEP_NAME="$1"
  STEP_START=$SECONDS
}

section "swift build -c release (zero warnings required, strict concurrency, warnings as errors)"
# SPM's incremental build does not always re-run diagnostics on unchanged files just because
# -Xswiftc flags changed, so a warm .build/ can silently hide a warning this exact build would
# catch on CI's always-fresh checkout — wipe it here so this step has the same fidelity as CI.
rm -rf .build
swift build -c release --arch arm64 \
  -Xswiftc -strict-concurrency=complete \
  -Xswiftc -enable-upcoming-feature -Xswiftc ImmutableWeakCaptures \
  -Xswiftc -enable-upcoming-feature -Xswiftc InferIsolatedConformances \
  -Xswiftc -enable-upcoming-feature -Xswiftc NonisolatedNonsendingByDefault \
  -Xswiftc -enable-upcoming-feature -Xswiftc StrictMemorySafety \
  -Xswiftc -enable-upcoming-feature -Xswiftc ExistentialAny \
  -Xswiftc -warnings-as-errors \
  2>&1 | tee /tmp/wiles_build.log
BUILD_STATUS=$?
if [[ "$BUILD_STATUS" -ne 0 ]] || grep -qi "warning:" /tmp/wiles_build.log; then
  echo "FAIL: build failed or produced warnings:"
  grep -i "warning:\|error:" /tmp/wiles_build.log
  FAILED=1
else
  echo "swift build OK"
fi

section "swift build (CI-toolchain check — catches Swift-version-specific diagnostics)"
# CI's release runner selects the newest Xcode available on it, which can lag behind what's
# installed locally (see release.yml's "Select Xcode" step) — its region-based concurrency
# checker has repeatedly flagged patterns (e.g. a weak `self` reused across a nested
# MainActor closure) that the local, newer compiler proves safe and says nothing about. This
# reruns the same build against a real installed CI-equivalent toolchain, so that class of
# failure surfaces here instead of after a push. Mandatory (this step fails if the toolchain
# isn't installed), not skipped — a green validate.sh must mean CI will actually pass too.
#
# To install: download the .pkg for the version CI is
# currently running (see "swift --version" in the release.yml log) from
# https://www.swift.org/install/macos/, `sudo installer -pkg <file> -target /`, then read the
# identifier back out of /Library/Developer/Toolchains/<name>.xctoolchain/Info.plist
# (CFBundleIdentifier). Update CI_TOOLCHAIN_ID below to match.
CI_TOOLCHAIN_ID="org.swift.624202602241a"
# `xcrun --toolchain <bogus-id>` silently falls back to the default toolchain instead of
# failing, so this checks the installed toolchains' own Info.plist identifiers directly rather
# than trusting xcrun to tell us the requested one doesn't exist.
CI_TOOLCHAIN_FOUND=0
for _toolchain_plist in /Library/Developer/Toolchains/*.xctoolchain/Info.plist; do
  [[ -f "$_toolchain_plist" ]] || continue
  if [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$_toolchain_plist" 2>/dev/null)" == "$CI_TOOLCHAIN_ID" ]]; then
    CI_TOOLCHAIN_FOUND=1
    break
  fi
done
if [[ "$CI_TOOLCHAIN_FOUND" -eq 0 ]]; then
  echo "FAIL: CI-equivalent toolchain ($CI_TOOLCHAIN_ID) not installed locally — install it (see comment above) to run this check"
  FAILED=1
else
  # This toolchain (installed from swift.org, not bundled with Xcode) can't see the private
  # SwiftUI/QuickLook overlay Xcode ships — `.quickLookPreview` is the one call site that
  # needs stubbing out for this build to get past it. Add more entries here if a future Xcode-
  # only API trips the same wall; each is restored unconditionally via the trap below.
  CI_TOOLCHAIN_PATCH_FILE="Sources/Wiles/Views/Content/MainContentView.swift"
  CI_TOOLCHAIN_PATCH_BACKUP="$(mktemp)"
  cp "$CI_TOOLCHAIN_PATCH_FILE" "$CI_TOOLCHAIN_PATCH_BACKUP"
  restore_ci_toolchain_patch() {
    cp "$CI_TOOLCHAIN_PATCH_BACKUP" "$CI_TOOLCHAIN_PATCH_FILE"
    rm -f "$CI_TOOLCHAIN_PATCH_BACKUP"
  }
  trap restore_ci_toolchain_patch EXIT
  sed -i '' 's|\.quickLookPreview(\$windowUIState\.quickLookURL)|.onAppear { _ = windowUIState.quickLookURL }|' "$CI_TOOLCHAIN_PATCH_FILE"

  CI_BUILD_LOG="$(mktemp)"
  TOOLCHAINS="$CI_TOOLCHAIN_ID" xcrun swift build -c release --arch arm64 \
    -Xswiftc -strict-concurrency=complete \
    -Xswiftc -enable-upcoming-feature -Xswiftc ImmutableWeakCaptures \
    -Xswiftc -enable-upcoming-feature -Xswiftc InferIsolatedConformances \
    -Xswiftc -enable-upcoming-feature -Xswiftc NonisolatedNonsendingByDefault \
    -Xswiftc -enable-upcoming-feature -Xswiftc StrictMemorySafety \
    -Xswiftc -enable-upcoming-feature -Xswiftc ExistentialAny \
    -Xswiftc -warnings-as-errors \
    2>&1 | tee "$CI_BUILD_LOG"
  CI_BUILD_STATUS=$?

  restore_ci_toolchain_patch
  trap - EXIT

  if [[ "$CI_BUILD_STATUS" -ne 0 ]] || grep -qi "warning:" "$CI_BUILD_LOG"; then
    echo "FAIL: build failed or produced warnings on the CI-equivalent toolchain:"
    grep -i "warning:\|error:" "$CI_BUILD_LOG"
    FAILED=1
  else
    echo "CI-toolchain build OK"
  fi
fi

section "swift test (unit tests — WilesTests, with code coverage)"
scripts/setup_test_ramdisk.sh
TEST_LOG="$(mktemp)"
swift test --enable-code-coverage --filter WilesTests 2>&1 | tee "$TEST_LOG" || true
if grep -q "FAIL\|error:" "$TEST_LOG" 2>/dev/null && ! grep -q "Build complete" "$TEST_LOG" 2>/dev/null; then
  echo "FAIL: unit tests did not pass"
  FAILED=1
elif grep -qE "^.*(FAILED|❌)" "$TEST_LOG" 2>/dev/null; then
  echo "FAIL: unit tests did not pass"
  FAILED=1
else
  echo "swift test OK"
fi
# Compute coverage regardless of pass/fail — profdata is written even when some tests fail.
# Only WilesTests (unit tests) feed this profile; the AXUIElement UI walkthrough below is a
# separate process (it launches the real app) and isn't merged in here. Printed at the end.
BIN=".build/debug/WilesPackageTests.xctest/Contents/MacOS/WilesPackageTests"
PROFDATA=".build/debug/codecov/default.profdata"
if [[ -f "$BIN" && -f "$PROFDATA" ]]; then
  COVERAGE_LINE=$(xcrun llvm-cov report "$BIN" -instr-profile="$PROFDATA" -ignore-filename-regex=".build|Tests/" | tail -1)
  COVERAGE_PCT=$(echo "$COVERAGE_LINE" | awk '{print $NF}')
fi
scripts/test_timing.sh "$TEST_LOG"

section "UI walkthrough (UITestRunner — drives the real Wiles.app via the Accessibility API)"
# Two passes against one build: the FEATURES.md feature tour, then the deeper UI_TEST_PLAN.md
# suite. Each is continue-on-failure and prints its own 'N checks · N passed · N failed' line;
# the script exits non-zero if any check failed. Needs Accessibility trust for the controlling
# terminal (the runner prints how to grant it) and a real login session — local gate only, not CI.
UITEST_OK=1
scripts/run_ui_test.sh 2>&1 | tee /tmp/wiles_uitest_features.log | grep -E 'checks ·|✗|▶' || true
[[ "${PIPESTATUS[0]}" -eq 0 ]] || UITEST_OK=0
scripts/run_ui_test.sh --no-build --plan 2>&1 | tee /tmp/wiles_uitest_plan.log | grep -E 'checks ·|✗|▶' || true
[[ "${PIPESTATUS[0]}" -eq 0 ]] || UITEST_OK=0
if [[ "$UITEST_OK" -eq 0 ]]; then
  echo "FAIL: UI walkthrough had failing checks — see /tmp/wiles_uitest_features.log and /tmp/wiles_uitest_plan.log"
  FAILED=1
else
  echo "UI walkthrough OK"
fi

section "L10n key references (R-LINT-2 — no orphan L10n.Key cases / dead translations)"
if ! scripts/check_l10n_keys.sh; then
  echo "FAIL: orphan L10n.Key case(s) — see above"
  FAILED=1
else
  echo "check_l10n_keys OK"
fi

section "SwiftLint (required — never releases with lint non-zero)"
if ! command -v swiftlint >/dev/null 2>&1; then
  echo "FAIL: swiftlint not installed (brew install swiftlint) — lint is mandatory, not optional, for a release"
  FAILED=1
else
  if ! swiftlint lint --strict; then
    echo "FAIL: swiftlint found issues"
    FAILED=1
  else
    echo "SwiftLint OK"
  fi
fi

section "SwiftFormat (check only, no changes written)"
if ! command -v swiftformat >/dev/null 2>&1; then
  echo "FAIL: swiftformat not installed (brew install swiftformat) — format check is mandatory, not optional, for a release"
  FAILED=1
else
  if ! swiftformat --lint .; then
    echo "FAIL: files are not formatted (run 'swiftformat .' to fix)"
    FAILED=1
  else
    echo "SwiftFormat OK"
  fi
fi

echo "(\"$STEP_NAME\" took $((SECONDS - STEP_START))s)"

echo
if [[ -n "$COVERAGE_LINE" ]]; then
  echo "-- Code coverage summary (WilesTests unit tests only — see note above) --"
  echo "$COVERAGE_LINE"
  echo "(full report: xcrun llvm-cov report \"$BIN\" -instr-profile=\"$PROFDATA\" -ignore-filename-regex=\".build|Tests/\")"
fi

echo
if [[ "$FAILED" -eq 0 ]]; then
  echo "==> All checks passed."
else
  echo "==> One or more checks failed. See above."
fi
echo "==> Code coverage: $COVERAGE_PCT"
echo "==> Total time: $((SECONDS - VALIDATE_START))s"

exit "$FAILED"
