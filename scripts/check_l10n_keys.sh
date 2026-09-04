#!/usr/bin/env bash
# R-LINT-2 — every `L10n.Key` case must be referenced as `.<case>` somewhere in `Sources/`
# outside `L10n.swift`. A case with no reference is a dead translation carried in all 15
# `.lproj/Localizable.strings` files that every future localization audit re-checks for nothing
# (finding LL-104). Cross-file, so it can't be a SwiftLint rule.
#
# Usage: scripts/check_l10n_keys.sh
# Exit 0 = every key is referenced. Non-zero = orphan keys listed on stderr.
#
# A key genuinely reached only via `rawValue` / string interpolation (none today) can be added
# to ALLOWLIST below with a one-line reason.

set -uo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

ENUM_FILE="Sources/Wiles/Services/L10n.swift"
ENUM_BASENAME="$(basename "$ENUM_FILE")"
ALLOWLIST=()  # e.g. "someKey"  # built dynamically from <enum>.rawValue in <file>

# Case names inside `enum Key: String … { … }` (from that line to its first closing brace at
# the enum's indentation). `sed` slices the block; `grep`/`sed` pull the identifiers.
cases="$(
  sed -n '/enum Key[[:space:]]*:[[:space:]]*String/,/^    }/p' "$ENUM_FILE" \
    | grep -E '^[[:space:]]*case [A-Za-z0-9_]+[[:space:]]*$' \
    | sed -E 's/^[[:space:]]*case ([A-Za-z0-9_]+)[[:space:]]*$/\1/'
)"

key_count="$(printf '%s\n' "$cases" | grep -c .)"
orphans=()
while IFS= read -r name; do
  [[ -z "$name" ]] && continue
  skip=0
  for allowed in "${ALLOWLIST[@]:-}"; do
    [[ "$name" == "$allowed" ]] && skip=1 && break
  done
  (( skip )) && continue
  if ! grep -rEq "\.${name}([^A-Za-z0-9_]|\$)" Sources/Wiles --include='*.swift' \
       --exclude="$ENUM_BASENAME"; then
    orphans+=("$name")
  fi
done <<< "$cases"

if (( ${#orphans[@]} > 0 )); then
  echo "FAIL: ${#orphans[@]} L10n.Key case(s) are never referenced in Sources/ (dead translations in every .lproj):" >&2
  printf '  - %s\n' "${orphans[@]}" >&2
  echo "Remove the case + its entry in all Sources/Wiles/Resources/*.lproj/Localizable.strings, or allowlist it in this script." >&2
  exit 1
fi

echo "check_l10n_keys OK ($key_count keys, all referenced)"
