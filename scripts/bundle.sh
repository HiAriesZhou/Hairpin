#!/usr/bin/env bash
# Builds Hairpin in release mode and packages Hairpin.app + Hairpin.zip
# in the repository root. Usage: VERSION=0.1.0 scripts/bundle.sh
# SIGN_IDENTITY picks a signing identity (default "-", ad-hoc); any other one
# signs with the hardened runtime and a timestamp, as notarization needs. Signing local
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
# SwiftPM links the binary framework, but a distributable .app must embed it.
SPARKLE="$ROOT/.build/artifacts/sparkle/Sparkle"
mkdir -p "$APP/Contents/Frameworks"
ditto "$SPARKLE/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework" \
      "$APP/Contents/Frameworks/Sparkle.framework"
cp "$SPARKLE/LICENSE" "$APP/Contents/Resources/Sparkle-LICENSE"
PUBLIC_KEY="$(cat "$ROOT/scripts/sparkle-public-key.txt")"
if [[ ! "$PUBLIC_KEY" =~ ^[A-Za-z0-9+/]{43}=$ ]]; then
  echo "error: invalid Sparkle public key" >&2
  exit 1
fi

echo "==> Drawing the app icon"
ICON_BUILD="$ROOT/.build/app-icon"
rm -rf "$ICON_BUILD"
mkdir -p "$ICON_BUILD"
swiftc -O "$ROOT/Sources/Hairpin/HairpinIcon.swift" "$ROOT/scripts/AppIcon/main.swift" -o "$ICON_BUILD/make-icon"
"$ICON_BUILD/make-icon" "$ICON_BUILD/AppIcon.iconset"
iconutil -c icns "$ICON_BUILD/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>Hairpin</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
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
    <key>SUFeedURL</key>
    <string>https://github.com/HiAriesZhou/Hairpin/releases/latest/download/appcast.xml</string>
    <key>SUPublicEDKey</key>
    <string>$PUBLIC_KEY</string>
    <key>SURequireSignedFeed</key>
    <true/>
    <key>SUVerifyUpdateBeforeExtraction</key>
    <true/>
    <key>SUEnableAutomaticChecks</key>
    <true/>
    <key>SUScheduledCheckInterval</key>
    <integer>86400</integer>
    <key>SUAutomaticallyUpdate</key>
    <false/>
    <key>SUEnableSystemProfiling</key>
    <false/>
    <key>SUSendProfileInfo</key>
    <false/>
    <key>SUEnableJavaScript</key>
    <false/>
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
SIGN_FLAGS=(--force -s "$SIGN_IDENTITY")
if [[ "$SIGN_IDENTITY" != "-" ]]; then
  SIGN_FLAGS+=(--options runtime --timestamp)
fi
# Sign nested code inside-out. Preserve Downloader's sandbox entitlements.
FRAMEWORK="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
codesign "${SIGN_FLAGS[@]}" "$FRAMEWORK/XPCServices/Installer.xpc"
codesign "${SIGN_FLAGS[@]}" --preserve-metadata=entitlements "$FRAMEWORK/XPCServices/Downloader.xpc"
codesign "${SIGN_FLAGS[@]}" "$FRAMEWORK/Autoupdate"
codesign "${SIGN_FLAGS[@]}" "$FRAMEWORK/Updater.app"
codesign "${SIGN_FLAGS[@]}" "$APP/Contents/Frameworks/Sparkle.framework"
if [[ "$SIGN_IDENTITY" == "-" ]]; then
  echo "==> Signing (ad-hoc)"
  codesign --force -s - "$APP"
else
  # Notarization needs the hardened runtime and a secure timestamp.
  echo "==> Signing ($SIGN_IDENTITY, hardened runtime)"
  codesign --force --options runtime --timestamp -s "$SIGN_IDENTITY" "$APP"
fi
codesign --verify --deep --strict --verbose=2 "$APP"

echo "==> Zipping $ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
ls -lh "$ZIP"
