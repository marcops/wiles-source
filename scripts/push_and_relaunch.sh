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

echo "==> 2. Building Wiles..."
swift build -c debug

echo "==> 3. Updating bundle & signing..."
rm -rf Wiles.app/Wiles_Wiles.bundle 2>/dev/null || true
cp .build/arm64-apple-macosx/debug/Wiles Wiles.app/Contents/MacOS/
cp -r .build/arm64-apple-macosx/debug/Wiles_Wiles.bundle Wiles.app/Contents/Resources/ 2>/dev/null || true
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
