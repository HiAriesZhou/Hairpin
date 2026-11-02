#!/usr/bin/env bash
# Generate and verify a signed feed from the final, notarized Hairpin.dmg.
# Usage: scripts/appcast.sh vX.Y.Z RELEASE_NOTES_TEXT [PREVIOUS_FEED]
# Locally uses Keychain account hairpin-updates. CI passes SPARKLE_PRIVATE_KEY
# through stdin to Sparkle; never put a private key in an argument or a file.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
TAG="${1:?release tag required}"
NOTES="${2:?release notes text file required}"
PREVIOUS="${3:-}"
[[ "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "error: stable vX.Y.Z tag required" >&2; exit 1; }
TOOLS="$ROOT/.build/artifacts/sparkle/Sparkle/bin"
KEY="$ROOT/scripts/sparkle-public-key.txt"
FEED_DIR="$(mktemp -d)"
trap 'rm -rf "$FEED_DIR"' EXIT
if [[ -n "$PREVIOUS" ]]; then
  swift scripts/ValidateUpdateFeed.swift verify "$PREVIOUS" "$KEY"
  cp "$PREVIOUS" "$FEED_DIR/appcast.xml"
fi
cp Hairpin.dmg "$FEED_DIR/Hairpin.dmg"
cp "$NOTES" "$FEED_DIR/Hairpin.txt"
URL="https://github.com/HiAriesZhou/Hairpin/releases/download/$TAG/"
ARGS=(--download-url-prefix "$URL" --embed-release-notes --maximum-deltas 0 --maximum-versions 3)
if [[ -n "${SPARKLE_PRIVATE_KEY:-}" ]]; then
  printf '%s' "$SPARKLE_PRIVATE_KEY" | "$TOOLS/generate_appcast" --ed-key-file - "${ARGS[@]}" "$FEED_DIR"
else
  "$TOOLS/generate_appcast" --account hairpin-updates "${ARGS[@]}" "$FEED_DIR"
fi
BUILD="$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' Hairpin.app/Contents/Info.plist)"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Hairpin.app/Contents/Info.plist)"
[[ "$VERSION" == "${TAG#v}" ]] || { echo "error: tag and bundle version differ" >&2; exit 1; }
VALIDATE=(validate "$FEED_DIR/appcast.xml" Hairpin.dmg "$BUILD" "$VERSION" "${URL}Hairpin.dmg" "$KEY")
if [[ -n "$PREVIOUS" ]]; then VALIDATE+=("$PREVIOUS"); fi
swift scripts/ValidateUpdateFeed.swift "${VALIDATE[@]}"
mkdir -p .build/update-feed
cp "$FEED_DIR/appcast.xml" .build/update-feed/appcast.xml
echo "==> Verified feed: .build/update-feed/appcast.xml"
