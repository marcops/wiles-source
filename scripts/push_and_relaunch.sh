#!/usr/bin/env bash
set -e

MSG="${1:-refactor: update source code}"
SKIP_COMMIT=false
for arg in "$@"; do
  if [ "$arg" = "--skip-commit" ]; then
    SKIP_COMMIT=true
  fi
done
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "==> 1. Closing any running Wiles instance..."
killall -9 Wiles 2>/dev/null || true
sleep 0.5

echo "==> 2. Building Wiles (strict concurrency, warnings as errors)..."
swift build -c debug \
  -Xswiftc -strict-concurrency=complete \
  -Xswiftc -enable-upcoming-feature -Xswiftc ImmutableWeakCaptures \
  -Xswiftc -enable-upcoming-feature -Xswiftc InferIsolatedConformances \
  -Xswiftc -enable-upcoming-feature -Xswiftc NonisolatedNonsendingByDefault \
  -Xswiftc -enable-upcoming-feature -Xswiftc StrictMemorySafety \
  -Xswiftc -enable-upcoming-feature -Xswiftc ExistentialAny \
  -Xswiftc -warnings-as-errors

echo "==> 3. Updating bundle & signing..."
# Remove any stray item at the bundle root left behind by an older build — codesign rejects
# anything there besides Contents/ ("unsealed contents present in the bundle root").
find Wiles.app -maxdepth 1 -mindepth 1 ! -name Contents -exec rm -rf {} +
rm -rf Wiles.app/Wiles_Wiles.bundle 2>/dev/null || true
cp .build/arm64-apple-macosx/debug/Wiles Wiles.app/Contents/MacOS/
cp -r .build/arm64-apple-macosx/debug/Wiles_Wiles.bundle Wiles.app/Contents/Resources/ 2>/dev/null || true

# Info.plist (repo root) is the single source of truth (also used by release.yml) — regenerate
# on every rebuild instead of relying on a hand-maintained bundle copy that can drift out of sync.
VERSION=$(grep -o 'appVersion = "[^"]*"' Sources/Wiles/Constants/AppConstants.swift | cut -d'"' -f2)
sed "s/__VERSION__/$VERSION/g" Info.plist > Wiles.app/Contents/Info.plist
if [[ -f "Sources/Wiles/Resources/AppIcon.icns" ]]; then
  cp Sources/Wiles/Resources/AppIcon.icns Wiles.app/Contents/Resources/AppIcon.icns
fi

codesign -f -s - Wiles.app

echo "==> 4. Relaunching Wiles.app..."
killall -9 Wiles 2>/dev/null || true
sleep 0.5
open Wiles.app

if [ "$SKIP_COMMIT" = true ]; then
  echo "==> 5. Skipping commit and push (--skip-commit)."
else
  echo "==> 5. Committing and pushing..."
  git add Sources/Wiles Tests .agents Package.swift scripts
  git commit -m "$MSG" --no-verify
  git push
fi

echo "==> Done!"
