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

section() {
  echo
  echo "==> $1"
}

section "swift build (zero warnings required)"
if swift build -c release 2>&1 | tee /tmp/wiles_build.log | grep -qi "warning:"; then
  echo "FAIL: build produced warnings:"
  grep -i "warning:" /tmp/wiles_build.log
  FAILED=1
else
  echo "OK"
fi

section "swift test (unit tests only, with code coverage)"
# WilesUITests requires a target application path the local `swift test` harness doesn't provide
# (that's an XCUITest/Xcode-runner requirement, not something wrong with the app) — it always
# fails here regardless of app correctness, so it would block every release. Unit tests
# (WilesTests) are the ones that actually validate app logic; filter to just those.
TEST_LOG="$(mktemp)"
if ! swift test --enable-code-coverage --filter WilesTests 2>&1 | tee "$TEST_LOG"; then
  echo "FAIL: tests did not pass"
  FAILED=1
else
  echo "OK"
  BIN=".build/debug/WilesPackageTests.xctest/Contents/MacOS/WilesPackageTests"
  PROFDATA=".build/debug/codecov/default.profdata"
  if [[ -f "$BIN" && -f "$PROFDATA" ]]; then
    echo
    echo "-- Code coverage summary --"
    xcrun llvm-cov report "$BIN" -instr-profile="$PROFDATA" -ignore-filename-regex=".build|Tests/" | tail -1
    echo "(full report: xcrun llvm-cov report \"$BIN\" -instr-profile=\"$PROFDATA\" -ignore-filename-regex=\".build|Tests/\")"
  fi
fi
scripts/test_timing.sh "$TEST_LOG"

section "SwiftLint"
if ! command -v swiftlint >/dev/null 2>&1; then
  echo "SKIP: swiftlint not installed (brew install swiftlint)"
else
  if ! swiftlint lint --strict; then
    echo "FAIL: swiftlint found issues"
    FAILED=1
  else
    echo "OK"
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
    echo "OK"
  fi
fi

echo
if [[ "$FAILED" -eq 0 ]]; then
  echo "==> All checks passed."
else
  echo "==> One or more checks failed. See above."
fi

exit "$FAILED"
