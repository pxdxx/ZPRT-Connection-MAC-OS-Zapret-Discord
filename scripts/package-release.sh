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
# Plain `xcodebuild build` (no -destination) silently builds active-arch-only
# on the new build system, even though the project's ARCHS say "arm64 x86_64" -
# that shipped arm64-only DMGs that just refuse to open on Intel Macs. Force
# both explicitly so the result is an actual universal binary.
xcodebuild \
  -project "$ROOT/dsffdssd.xcodeproj" \
  -scheme dsffdssd \
  -configuration Release \
  -derivedDataPath "$DD" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_ALLOWED=YES \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  build

test -d "$PRODUCT"

echo "==> Verifying universal binary..."
ARCHES="$(lipo -archs "$PRODUCT/Contents/MacOS/ZPRT Connection")"
case "$ARCHES" in
  *arm64*x86_64*|*x86_64*arm64*) ;;
  *) echo "error: built binary is not universal (archs: $ARCHES)" >&2; exit 1 ;;
esac

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
