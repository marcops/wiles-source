#!/usr/bin/env bash
set -e

MSG="${1:-refactor: update source code}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "==> 1. Building Wiles..."
swift build -c debug

echo "==> 2. Updating bundle & signing..."
cp .build/arm64-apple-macosx/debug/Wiles Wiles.app/Contents/MacOS/
cp -r .build/arm64-apple-macosx/debug/Wiles_Wiles.bundle Wiles.app/Contents/Resources/ 2>/dev/null || true
codesign -f -s - Wiles.app

echo "==> 3. Relaunching Wiles.app..."
killall Wiles 2>/dev/null || true
sleep 0.5
open Wiles.app

echo "==> 4. Committing and pushing..."
git add Sources/Wiles Tests .agents Package.swift
git commit -m "$MSG" --no-verify
git push

echo "==> Done!"
