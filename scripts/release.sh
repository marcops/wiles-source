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

# Re-hash the copies actually sitting in wiles-public before they get committed — the Cask's
# sha256 (and every user's Homebrew install) is only as trustworthy as this file, so a bad copy
# must be caught here, not discovered later as a Homebrew SHA256 mismatch in the wild.
PUBLISHED_ZIP_SHA256=$(shasum -a 256 "$PUBLIC_DIR/releases/wiles-v${VERSION}.zip" | awk '{print $1}')
if [[ "$PUBLISHED_ZIP_SHA256" != "$SHA256" ]]; then
  echo "error: published zip sha256 mismatch after copy! expected $SHA256, got $PUBLISHED_ZIP_SHA256" >&2
  exit 1
fi
BUILT_DMG_SHA256=$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')
PUBLISHED_DMG_SHA256=$(shasum -a 256 "$PUBLIC_DIR/releases/wiles-v${VERSION}.dmg" | awk '{print $1}')
if [[ "$PUBLISHED_DMG_SHA256" != "$BUILT_DMG_SHA256" ]]; then
  echo "error: published dmg sha256 mismatch after copy! expected $BUILT_DMG_SHA256, got $PUBLISHED_DMG_SHA256" >&2
  exit 1
fi
echo "OK: published zip/dmg sha256 match the build output"

cd "$PUBLIC_DIR"

# Push the binaries + release notes FIRST, in their own commit, so we can pin the Cask's
# download URL to the exact commit SHA they landed on (see below) instead of `main` — GitHub's
# Fastly CDN caches raw.githubusercontent.com content per-path, and a `main`-pinned URL can keep
# serving a stale cached binary after a new release, causing a Homebrew SHA256 mismatch error
# for users. This is a known, previously-hit failure mode — never revert to a `main` URL.
git add releases/ RELEASE_NOTES.md
if git diff --cached --quiet; then
  echo "Nothing changed in releases/ or RELEASE_NOTES.md — skipping binary commit/push."
else
  git commit -m "release: add v${VERSION} binaries

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
  git push origin main
  echo "Pushed binaries."
fi

COMMIT_SHA=$(git rev-parse HEAD)
echo "Binaries live at commit $COMMIT_SHA"

cat > "$PUBLIC_DIR/Casks/wiles.rb" <<CASK
cask "wiles" do
  version "${VERSION}"
  sha256 "${SHA256}"

  url "https://raw.githubusercontent.com/marcops/wiles/${COMMIT_SHA}/releases/wiles-v#{version}.zip"
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

git add Casks/wiles.rb
if git diff --cached --quiet; then
  echo "Nothing changed in Casks/wiles.rb — skipping cask commit/push."
else
  git commit -m "cask(wiles): update to v${VERSION}

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
  git push origin main
  echo "Pushed cask update."
fi

echo
echo "=================================================="
echo " STEP 6/6: Done. Wiles v${VERSION}"
echo "   zip:  $ZIP_PATH"
echo "   dmg:  $DMG_PATH"
echo "   sha256: $SHA256"
echo "=================================================="
