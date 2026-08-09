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

section "swift build -c release (zero warnings required)"
swift build -c release --arch arm64 2>&1 | tee /tmp/wiles_build.log
if grep -qi "warning:" /tmp/wiles_build.log; then
  echo "FAIL: build produced warnings:"
  grep -i "warning:" /tmp/wiles_build.log
  FAILED=1
else
  echo "swift build OK"
fi

section "swift test (unit tests — WilesTests, with code coverage)"
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
  echo "SKIP: swiftformat not installed (brew install swiftformat)"
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
