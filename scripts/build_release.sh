#!/usr/bin/env bash
# Builds Wiles.app in release mode and packages it as .zip (for the Homebrew
# cask) and .dmg (for direct download). Run from the repo root.
#
# Usage: scripts/build_release.sh
# Reads the version from Sources/Wiles/Constants/AppConstants.swift.
# Outputs into ./dist/: wiles-vX.Y.Z.zip, wiles-vX.Y.Z.dmg, and a .sha256 file.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

VERSION=$(grep -o 'appVersion = "[^"]*"' Sources/Wiles/Constants/AppConstants.swift | cut -d'"' -f2)
if [[ -z "$VERSION" ]]; then
  echo "error: could not read appVersion from AppConstants.swift" >&2
  exit 1
fi
echo "==> Building Wiles v$VERSION"

DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/Wiles.app"
rm -rf "$APP_DIR"
mkdir -p "$DIST_DIR" "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

echo "==> swift build -c release"
swift build -c release

cp ".build/release/Wiles" "$APP_DIR/Contents/MacOS/Wiles"
cp "Sources/Wiles/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>Wiles</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundleIconName</key>
	<string>AppIcon</string>
	<key>CFBundleIdentifier</key>
	<string>com.marco.wiles</string>
	<key>CFBundleName</key>
	<string>Wiles</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>$VERSION</string>
	<key>CFBundleVersion</key>
	<string>$VERSION</string>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>NSDesktopFolderUsageDescription</key>
	<string>Wiles precisa de acesso para gerenciar arquivos na sua pasta Mesa (Desktop).</string>
	<key>NSDocumentsFolderUsageDescription</key>
	<string>Wiles precisa de acesso para gerenciar arquivos na sua pasta Documentos.</string>
	<key>NSDownloadsFolderUsageDescription</key>
	<string>Wiles precisa de acesso para gerenciar arquivos na sua pasta Downloads.</string>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
	<key>NSRemovableVolumesUsageDescription</key>
	<string>Wiles precisa de acesso para gerenciar arquivos em discos externos.</string>
</dict>
</plist>
PLIST

echo "==> ad-hoc codesign"
codesign --force --deep --sign - "$APP_DIR"

ZIP_PATH="$DIST_DIR/wiles-v$VERSION.zip"
DMG_PATH="$DIST_DIR/wiles-v$VERSION.dmg"
rm -f "$ZIP_PATH" "$DMG_PATH"

echo "==> creating zip (for Homebrew cask)"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ZIP_PATH"

echo "==> creating dmg (for direct download)"
STAGING_DIR=$(mktemp -d)
cp -R "$APP_DIR" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"
hdiutil create -volname "Wiles" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_PATH"
rm -rf "$STAGING_DIR"

SHA256=$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')
echo "$SHA256" > "$DIST_DIR/wiles-v$VERSION.sha256"

echo "==> done"
echo "version=$VERSION"
echo "zip=$ZIP_PATH"
echo "dmg=$DMG_PATH"
echo "sha256=$SHA256"
