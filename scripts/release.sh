#!/usr/bin/env bash
# One-shot local release: validate -> build & package -> verify sha256 ->
# update the Homebrew Cask -> commit & push to wiles-public.
#
# Usage: scripts/release.sh
#
# Assumes wiles-public is checked out as a sibling directory:
#   ~/source/wiles          (this repo)
#   ~/source/wiles-public   (override with WILES_PUBLIC_DIR env var)

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PUBLIC_DIR="${WILES_PUBLIC_DIR:-$ROOT_DIR/../wiles-public}"

if [[ ! -d "$PUBLIC_DIR/.git" ]]; then
  echo "error: wiles-public repo not found at $PUBLIC_DIR" >&2
  echo "set WILES_PUBLIC_DIR to override the path" >&2
  exit 1
fi

echo "=================================================="
echo " STEP 1/6: Validate (build, tests, lint, format)"
echo "=================================================="
"$ROOT_DIR/scripts/validate.sh"

echo
echo "=================================================="
echo " STEP 2/6: Build & package (.zip + .dmg)"
echo "=================================================="
"$ROOT_DIR/scripts/build_release.sh" | tee /tmp/wiles_build_release.out

VERSION=$(grep '^version=' /tmp/wiles_build_release.out | cut -d= -f2)
SHA256=$(grep '^sha256=' /tmp/wiles_build_release.out | cut -d= -f2)
ZIP_PATH="$ROOT_DIR/dist/wiles-v${VERSION}.zip"
DMG_PATH="$ROOT_DIR/dist/wiles-v${VERSION}.dmg"

echo
echo "=================================================="
echo " STEP 3/6: Verify SHA256"
echo "=================================================="
RECOMPUTED_SHA256=$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')
if [[ "$RECOMPUTED_SHA256" != "$SHA256" ]]; then
  echo "error: sha256 mismatch! build_release.sh reported $SHA256, recomputed $RECOMPUTED_SHA256" >&2
  exit 1
fi
echo "OK: sha256 verified -> $SHA256"

echo
echo "=================================================="
echo " STEP 4/6: Smoke test the packaged .app"
echo "=================================================="
# Catches the class of bug where the app runs fine from .build/ or the repo's own dist/ dir
# (both of which sit near dev-machine-only fallback paths a resource-bundle lookup might
# accidentally succeed against) but crashes once actually installed and launched from
# somewhere else, like /Applications. Runs the real packaged .app from a neutral temp
# location instead of overwriting whatever the user has installed.
SMOKE_DIR="$(mktemp -d)"
cp -R "$ROOT_DIR/dist/Wiles.app" "$SMOKE_DIR/Wiles.app"
open "$SMOKE_DIR/Wiles.app"
sleep 2
if pgrep -f "$SMOKE_DIR/Wiles.app/Contents/MacOS/Wiles" >/dev/null; then
  echo "OK: packaged app launched and is still running after 2s"
  pkill -f "$SMOKE_DIR/Wiles.app/Contents/MacOS/Wiles" || true
else
  echo "error: packaged app did not stay running — check Console.app for a crash log (likely a resource-bundle path or codesign issue)" >&2
  rm -rf "$SMOKE_DIR"
  exit 1
fi
rm -rf "$SMOKE_DIR"

echo
echo "=================================================="
echo " STEP 5/6: Publish to wiles-public"
echo "=================================================="

# Drop every previously published zip/dmg before copying the new ones in, so releases/
# never accumulates old versions.
rm -f "$PUBLIC_DIR"/releases/wiles-v*.zip "$PUBLIC_DIR"/releases/wiles-v*.dmg
cp "$ZIP_PATH" "$PUBLIC_DIR/releases/"
cp "$DMG_PATH" "$PUBLIC_DIR/releases/"

cat > "$PUBLIC_DIR/Casks/wiles.rb" <<CASK
cask "wiles" do
  version "${VERSION}"
  sha256 "${SHA256}"

  url "https://raw.githubusercontent.com/marcops/wiles/main/releases/wiles-v#{version}.zip"
  name "Wiles"
  desc "Ultra-fast modern macOS File Manager"
  homepage "https://github.com/marcops/wiles"

  depends_on macos: :sonoma

  app "Wiles.app"

  postflight do
    system_command "xattr",
                   args: ["-cr", "#{appdir}/Wiles.app"],
                   sudo: false
  end

  zap trash: [
    "~/Library/Preferences/com.marco.wiles.plist",
    "~/Library/Saved Application State/com.marco.wiles.savedState",
    "~/Library/Caches/Wiles",
  ]
end
CASK

cd "$PUBLIC_DIR"
git add releases/ Casks/wiles.rb

if git diff --cached --quiet; then
  echo "Nothing changed in wiles-public — skipping commit/push."
else
  git commit -m "release: v${VERSION}

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
  read -r -p "Push wiles-public to origin main now? [y/N] " CONFIRM
  if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
    git push origin main
    echo "Pushed."
  else
    echo "Not pushed. Run 'git push origin main' in $PUBLIC_DIR when ready."
  fi
fi

echo
echo "=================================================="
echo " STEP 6/6: Done. Wiles v${VERSION}"
echo "   zip:  $ZIP_PATH"
echo "   dmg:  $DMG_PATH"
echo "   sha256: $SHA256"
echo "=================================================="
