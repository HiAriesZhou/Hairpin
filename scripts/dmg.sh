#!/usr/bin/env bash
# Wraps Hairpin.app into Hairpin.dmg in the repository root: the app beside a
# link to /Applications, so installing is a single drag. Run scripts/bundle.sh
# first. With SIGN_IDENTITY set (as for bundle.sh), the disk image is signed
# too, ready for scripts/notarize.sh dmg. Usage: scripts/dmg.sh
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
APP="$ROOT/Hairpin.app"
DMG="$ROOT/Hairpin.dmg"
[[ -d "$APP" ]] || { echo "error: no app bundle at $APP (run scripts/bundle.sh first)" >&2; exit 1; }

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

echo "==> Staging"
ditto "$APP" "$STAGE/Hairpin.app"
ln -s /Applications "$STAGE/Applications"
codesign --verify --strict "$STAGE/Hairpin.app"

echo "==> Creating $DMG"
rm -f "$DMG"
hdiutil create -volname Hairpin -srcfolder "$STAGE" -fs HFS+ \
    -format UDZO -imagekey zlib-level=9 -ov "$DMG"
hdiutil verify "$DMG"
if [[ -n "${SIGN_IDENTITY:-}" && "$SIGN_IDENTITY" != "-" ]]; then
  echo "==> Signing the disk image ($SIGN_IDENTITY)"
  codesign --force --timestamp -s "$SIGN_IDENTITY" "$DMG"
  codesign --verify --verbose=2 "$DMG"
fi
ls -lh "$DMG"
