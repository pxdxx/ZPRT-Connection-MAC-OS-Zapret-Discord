#!/bin/sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
DD="${DERIVED_DATA_PATH:-/tmp/ZPRTBuild}"
DIST="$ROOT/dist"
APP_NAME="ZPRT Connection.app"
PRODUCT="$DD/Build/Products/Release/$APP_NAME"
DMG_NAME="ZPRT-Connection-macOS.dmg"
VOL_NAME="ZPRT Connection"
STAGE="$DIST/dmg-stage"

echo "==> Building Release..."
xcodebuild \
  -project "$ROOT/dsffdssd.xcodeproj" \
  -scheme dsffdssd \
  -configuration Release \
  -derivedDataPath "$DD" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_ALLOWED=YES \
  build

test -d "$PRODUCT"

echo "==> Staging DMG..."
rm -rf "$DIST"
mkdir -p "$STAGE"
ditto "$PRODUCT" "$STAGE/$APP_NAME"
ln -s /Applications "$STAGE/Applications"

echo "==> Creating $DMG_NAME..."
# Writable then compress for a clean Finder window
TMP_DMG="$DIST/${DMG_NAME%.dmg}-rw.dmg"
rm -f "$TMP_DMG" "$DIST/$DMG_NAME"
hdiutil create \
  -volname "$VOL_NAME" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDRW \
  "$TMP_DMG"

# Optional: set a larger Finder window; keep simple for reliability
hdiutil convert "$TMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DIST/$DMG_NAME"
rm -f "$TMP_DMG"
rm -rf "$STAGE"

# Keep unpacked app for local smoke tests
ditto "$PRODUCT" "$DIST/$APP_NAME"

echo "==> Done:"
ls -lh "$DIST/$DMG_NAME"
echo "$DIST/$DMG_NAME"
