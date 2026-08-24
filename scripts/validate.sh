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
# reruns the same build against a real installed CI-equivalent toolchain when available, so
# that class of failure surfaces here instead of after a push.
#
# Optional: `swift build` alone (rm -rf .build; swift build -c debug) with TOOLCHAINS set to
# this identifier is what installs it locally: download the .pkg for the version CI is
# currently running (see "swift --version" in the release.yml log) from
# https://www.swift.org/install/macos/, `sudo installer -pkg <file> -target /`, then read the
# identifier back out of /Library/Developer/Toolchains/<name>.xctoolchain/Info.plist
# (CFBundleIdentifier). Update CI_TOOLCHAIN_ID below to match.
CI_TOOLCHAIN_ID="org.swift.624202602241a"
if ! [[ -d "/Library/Developer/Toolchains" ]] || ! xcrun --toolchain "$CI_TOOLCHAIN_ID" --find swift >/dev/null 2>&1; then
  echo "SKIP: CI-equivalent toolchain ($CI_TOOLCHAIN_ID) not installed locally — this step is optional, everything else above already ran"
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
# Only WilesTests (unit tests) feed this profile; the xcodebuild UI test run below is a separate
# harness with its own coverage format and isn't merged in here. Printed at the end, not here.
BIN=".build/debug/WilesPackageTests.xctest/Contents/MacOS/WilesPackageTests"
PROFDATA=".build/debug/codecov/default.profdata"
if [[ -f "$BIN" && -f "$PROFDATA" ]]; then
  COVERAGE_LINE=$(xcrun llvm-cov report "$BIN" -instr-profile="$PROFDATA" -ignore-filename-regex=".build|Tests/" | tail -1)
  COVERAGE_PCT=$(echo "$COVERAGE_LINE" | awk '{print $NF}')
fi
scripts/test_timing.sh "$TEST_LOG"

section "xcodebuild UI tests (WilesUITests — launches Wiles.app and controls the screen)"
if ! xcodebuild test \
    -scheme Wiles \
    -only-testing:WilesUITests/WilesLaunchUITests \
    -only-testing:WilesUITests/GlobalKeyMonitorUITests \
    -skip-testing:WilesTests \
    -destination 'platform=macOS,arch=arm64' \
    2>&1 | tee /tmp/wiles_uitest.log | grep -E 'Test Case|passed|failed|error:'; then
  echo "FAIL: UI tests did not pass"
  FAILED=1
else
  echo "xcodebuild UI tests OK"
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
