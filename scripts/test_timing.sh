#!/usr/bin/env bash
# Runs the test suite and prints the 10 slowest individual test cases.
# A unit test taking more than a couple seconds is usually a smell (real
# network/timeout wait, missing mock, flaky sleep-based polling) — use this
# to catch that before it silently turns into a 60s+ hang later.
#
# Usage:
#   scripts/test_timing.sh                # runs the suite fresh
#   scripts/test_timing.sh /path/to.log    # parses an existing `swift test` log instead

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

LOG_FILE="${1:-}"

if [[ -z "$LOG_FILE" ]]; then
  LOG_FILE="$(mktemp)"
  echo "==> Running swift test (capturing per-test durations)..."
  swift test 2>&1 | tee "$LOG_FILE" >/dev/null
fi

echo
echo "==> Top 20 slowest test cases"
echo

# Matches lines from any XCTestCase class, not just the WilesAutomatedTests aggregator, e.g.:
#   Test Case '-[WilesTests.WilesAutomatedTests testFoo]' passed (1.234 seconds).
#   Test Case '-[WilesTests.FinderStyleTruncationServiceTests testBar]' passed (0.001 seconds).
grep -E "Test Case '.*' (passed|failed) \([0-9.]+ seconds\)\.$" "$LOG_FILE" \
  | sed -E "s/Test Case '-\[WilesTests\.([A-Za-z0-9_]+) (test[A-Za-z0-9_]+)\]' (passed|failed) \(([0-9.]+) seconds\)\./\4 \3 \1.\2/" \
  | sort -rn \
  | head -20 \
  | awk '{printf "  %7.3fs  %-7s %s\n", $1, $2, $3}'

echo
echo "(Anything above ~5s is worth a look — see scripts/test_timing.sh header.)"
