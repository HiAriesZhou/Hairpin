#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_DIR="$(mktemp -d)"
DOMAIN="org.hairpin.update-test.$(uuidgen)"
trap 'defaults delete "$DOMAIN" >/dev/null 2>&1 || true; rm -rf "$TEST_DIR"' EXIT
APP="$TEST_DIR/UpdateTests.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Frameworks"
FRAMEWORK=.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64
[[ -f Hairpin.app/Contents/Info.plist ]] || { echo 'error: run scripts/bundle.sh first' >&2; exit 1; }
ditto "$FRAMEWORK/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"
swiftc Sources/Hairpin/Updates.swift Sources/Hairpin/HairpinIcon.swift Tests/UpdateIntegration/main.swift \
  -F "$FRAMEWORK" -framework Sparkle -Xlinker -rpath -Xlinker @executable_path/../Frameworks \
  -o "$APP/Contents/MacOS/UpdateTests"
cp Hairpin.app/Contents/Info.plist "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set CFBundleIdentifier $DOMAIN" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set CFBundleExecutable UpdateTests' "$APP/Contents/Info.plist"
[[ "$(/usr/libexec/PlistBuddy -c 'Print SUPublicEDKey' "$APP/Contents/Info.plist")" == "$(cat scripts/sparkle-public-key.txt)" ]]
"$APP/Contents/MacOS/UpdateTests"
"$APP/Contents/MacOS/UpdateTests" persisted
"$APP/Contents/MacOS/UpdateTests" disabled

swift Tests/UpdateIntegration/FeedFixtures.swift "$TEST_DIR"
VALIDATE=(swift scripts/ValidateUpdateFeed.swift validate)
URL=https://github.com/HiAriesZhou/Hairpin/releases/download/v0.3.0/Hairpin.dmg
"${VALIDATE[@]}" "$TEST_DIR/valid.xml" "$TEST_DIR/Hairpin.dmg" 100 0.3.0 "$URL" "$TEST_DIR/public-key" "$TEST_DIR/previous.xml"
for FEED in tampered truncated unpinned bad-archive-signature; do
  if "${VALIDATE[@]}" "$TEST_DIR/$FEED.xml" "$TEST_DIR/Hairpin.dmg" 100 0.3.0 "$URL" "$TEST_DIR/public-key" > "$TEST_DIR/error" 2>&1; then
    echo "error: accepted invalid feed $FEED" >&2; exit 1
  fi
done
for PREVIOUS in same-build future; do
  if "${VALIDATE[@]}" "$TEST_DIR/valid.xml" "$TEST_DIR/Hairpin.dmg" 100 0.3.0 "$URL" "$TEST_DIR/public-key" "$TEST_DIR/$PREVIOUS.xml" > "$TEST_DIR/error" 2>&1; then
    echo "error: accepted non-increasing build" >&2; exit 1
  fi
done
if "${VALIDATE[@]}" "$TEST_DIR/valid.xml" "$TEST_DIR/broken.dmg" 100 0.3.0 "$URL" "$TEST_DIR/public-key" > "$TEST_DIR/error" 2>&1; then
  echo "error: accepted interrupted archive" >&2; exit 1
fi
echo "Update integration and release-gate checks passed"
