#!/bin/bash
# Builds Vitroscribe and packages it as a DMG using create-dmg (Sindre Sorhus).
#
# Usage: bash create_dmg.sh
#
# Requires:
#   brew install create-dmg
#
# Code signing:
#   By default an ad-hoc signature (-) is applied so macOS Gatekeeper shows
#   the "Open Anyway" dialog rather than the hard "can't be opened" block.
#   To sign with a real Developer ID certificate instead, set:
#     SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"

set -e

APP_NAME="Vitroscribe"
BUNDLE_ID="com.nikkipunjabi.Vitroscribe"
DERIVED="/tmp/vscribe_derived"
RELEASE="release"
ENTITLEMENTS="Vitroscribe/Vitroscribe.entitlements"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"   # default: ad-hoc

echo "→ Building $APP_NAME (Release)..."
xcodebuild \
  -project "${APP_NAME}.xcodeproj" \
  -scheme "${APP_NAME}" \
  -configuration Release \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  -derivedDataPath "$DERIVED" \
  | grep -E "(error:|warning:|BUILD SUCCEEDED|BUILD FAILED)" || true

APP_PATH="$DERIVED/Build/Products/Release/${APP_NAME}.app"

if [ ! -d "$APP_PATH" ]; then
  echo "✗ Build failed."
  exit 1
fi

# ── Code Signing ────────────────────────────────────────────────────────────
# Ad-hoc signing (-) gives the app a self-signed identity so:
#   • macOS Gatekeeper shows "Open Anyway" instead of the hard "can't be opened" block
#   • Entitlements (microphone, etc.) are actually embedded in the binary
#   • TCC can store a permission entry for this binary
#
# Signing order matters: sign nested bundles before the outer app.
echo "→ Signing $APP_NAME (identity: ${SIGN_IDENTITY})..."

# 1. Sign any XPC services / nested apps first
find "$APP_PATH/Contents" -name "*.xpc" -o -name "*.app" 2>/dev/null | while read -r nested; do
  codesign --force --sign "$SIGN_IDENTITY" "$nested" 2>/dev/null || true
done

# 2. Sign the main executable with entitlements
codesign --force \
  --sign "$SIGN_IDENTITY" \
  --entitlements "$ENTITLEMENTS" \
  "$APP_PATH/Contents/MacOS/${APP_NAME}"

# 3. Sign the outer app bundle (do NOT use --deep: it would override the
#    legitimate signatures on embedded frameworks like Sparkle)
codesign --force \
  --sign "$SIGN_IDENTITY" \
  --entitlements "$ENTITLEMENTS" \
  "$APP_PATH"

echo "→ Verifying signature..."
codesign --verify --verbose "$APP_PATH" 2>&1 | grep -v "^$" || true

# ── Package ─────────────────────────────────────────────────────────────────
echo "→ Copying .app to release/..."
mkdir -p "$RELEASE"
rm -rf "$RELEASE/${APP_NAME}.app"
cp -R "$APP_PATH" "$RELEASE/"

echo "→ Creating DMG..."
rm -f "$RELEASE/${APP_NAME}.dmg"

create-dmg \
  --overwrite \
  --no-code-sign \
  --dmg-title "$APP_NAME" \
  "$RELEASE/${APP_NAME}.app" \
  "$RELEASE/"

# create-dmg names the file "AppName X.Y.dmg" — rename to canonical Vitroscribe.dmg
VERSIONED=$(ls "$RELEASE/${APP_NAME} "*.dmg 2>/dev/null | head -1)
if [ -n "$VERSIONED" ]; then
  mv "$VERSIONED" "$RELEASE/${APP_NAME}.dmg"
fi

rm -rf "$DERIVED"

echo "✓ Done: $RELEASE/${APP_NAME}.dmg"
ls -lh "$RELEASE/${APP_NAME}.dmg"
echo ""
echo "Note: Recipients on macOS 15 will see an 'unidentified developer' prompt."
echo "They must right-click the app → Open → Open to bypass Gatekeeper once."
echo "To eliminate this entirely, sign with a Developer ID certificate:"
echo "  SIGN_IDENTITY=\"Developer ID Application: Name (TEAMID)\" bash create_dmg.sh"
