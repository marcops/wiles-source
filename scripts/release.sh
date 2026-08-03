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
echo " STEP 1/4: Validate (build, tests, lint, format)"
echo "=================================================="
"$ROOT_DIR/scripts/validate.sh"

echo
echo "=================================================="
echo " STEP 2/4: Build & package (.zip + .dmg)"
echo "=================================================="
"$ROOT_DIR/scripts/build_release.sh" | tee /tmp/wiles_build_release.out

VERSION=$(grep '^version=' /tmp/wiles_build_release.out | cut -d= -f2)
SHA256=$(grep '^sha256=' /tmp/wiles_build_release.out | cut -d= -f2)
ZIP_PATH="$ROOT_DIR/dist/wiles-v${VERSION}.zip"
DMG_PATH="$ROOT_DIR/dist/wiles-v${VERSION}.dmg"

echo
echo "=================================================="
echo " STEP 3/4: Verify SHA256"
echo "=================================================="
RECOMPUTED_SHA256=$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')
if [[ "$RECOMPUTED_SHA256" != "$SHA256" ]]; then
  echo "error: sha256 mismatch! build_release.sh reported $SHA256, recomputed $RECOMPUTED_SHA256" >&2
  exit 1
fi
echo "OK: sha256 verified -> $SHA256"

echo
echo "=================================================="
echo " STEP 4/4: Publish to wiles-public"
echo "=================================================="

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
    "~/Library/Preferences/com.wiles.app.plist",
    "~/Library/Saved Application State/com.wiles.app.savedState",
  ]
end
CASK

cd "$PUBLIC_DIR"
git add releases/ Casks/wiles.rb

if git diff --cached --quiet; then
  echo "Nothing changed in wiles-public — skipping commit/push."
else
  git commit -m "release: v${VERSION}"
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
echo " Done. Wiles v${VERSION}"
echo "   zip:  $ZIP_PATH"
echo "   dmg:  $DMG_PATH"
echo "   sha256: $SHA256"
echo "=================================================="
