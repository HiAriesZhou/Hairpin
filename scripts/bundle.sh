#!/usr/bin/env bash
# Builds Hairpin in release mode and packages Hairpin.app + Hairpin.zip
# in the repository root. Usage: VERSION=0.1.0 scripts/bundle.sh
# SIGN_IDENTITY picks a signing identity (default "-", ad-hoc). Signing local
# builds with a stable identity, e.g. "Apple Development", keeps macOS
# privacy grants (Accessibility, Screen Recording) across rebuilds.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
APP="$ROOT/Hairpin.app"
ZIP="$ROOT/Hairpin.zip"
# Version: $VERSION if set, else a tag on HEAD itself (vX.Y.Z), else 0.0.0.
# A pre-release or build suffix (-rc.1, +meta) is dropped, since
# CFBundleShortVersionString takes numbers only.
if [[ -z "${VERSION:-}" ]]; then
  VERSION="$(git describe --tags --exact-match HEAD 2>/dev/null || true)"
  VERSION="${VERSION#v}"
fi
VERSION="${VERSION:-0.0.0}"
VERSION="${VERSION%%[-+]*}"
BUILD_NUMBER="${BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"
COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"

# Both end up inside the Info.plist XML below, so accept numbers only.
version_re='^[0-9]+(\.[0-9]+){0,2}$'
if [[ ! "$VERSION" =~ $version_re ]]; then
  echo "error: VERSION '$VERSION' is not 1-3 dot-separated numbers" >&2
  exit 1
fi
if [[ ! "$BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
  echo "error: BUILD_NUMBER '$BUILD_NUMBER' is not a number" >&2
  exit 1
fi

echo "==> swift build -c release (version $VERSION, build $BUILD_NUMBER, commit $COMMIT)"
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

echo "==> Assembling $APP"
rm -rf "$APP" "$ZIP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Hairpin" "$APP/Contents/MacOS/Hairpin"
cp "$ROOT/LICENSE" "$APP/Contents/Resources/LICENSE"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>Hairpin</string>
    <key>CFBundleIdentifier</key>
    <string>com.hiarieszhou.hairpin</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Hairpin</string>
    <key>CFBundleDisplayName</key>
    <string>Hairpin</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 AriesZhou. MIT License.</string>
</dict>
</plist>
PLIST
printf 'APPL????' > "$APP/Contents/PkgInfo"
plutil -lint "$APP/Contents/Info.plist"

SIGN_IDENTITY="${SIGN_IDENTITY:--}"
echo "==> Signing (${SIGN_IDENTITY/#-/ad-hoc})"
codesign --force --deep -s "$SIGN_IDENTITY" "$APP"
codesign --verify --verbose=2 "$APP"

echo "==> Zipping $ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
ls -lh "$ZIP"
