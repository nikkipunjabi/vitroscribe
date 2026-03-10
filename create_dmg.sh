#!/bin/bash

# Configuration
APP_NAME="Vitroscribe"
BUILD_DIR="build"
APP_DIR="${BUILD_DIR}/Release/${APP_NAME}.app"
DMG_NAME="${APP_NAME}.dmg"

echo "Building Xcode Project..."
echo "Building Xcode Project..."
xcodebuild -project ${APP_NAME}.xcodeproj -scheme ${APP_NAME} -configuration Release CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO -derivedDataPath derived_data
if [ $? -ne 0 ]; then
  echo "Build Failed! Check the errors above."
  exit 1
fi

echo "Copying to build directory..."
mkdir -p build/Release
cp -R derived_data/Build/Products/Release/${APP_NAME}.app build/Release/

echo "Creating DMG..."
# Check if create-dmg is installed, else use hdiutil
if command -v create-dmg &> /dev/null; then
  create-dmg \
    --volname "${APP_NAME} Installer" \
    --window-pos 200 120 \
    --window-size 800 400 \
    --icon-size 100 \
    --icon "${APP_NAME}.app" 200 190 \
    --hide-extension "${APP_NAME}.app" \
    --app-drop-link 600 185 \
    "${DMG_NAME}" \
    "${APP_DIR}/"
else
  echo "create-dmg not found, using hdiutil"
  hdiutil create -volname "${APP_NAME} Installer" -srcfolder "${APP_DIR}" -ov -format UDZO "${DMG_NAME}"
fi

echo "Cleaning up..."
rm -rf derived_data
rm -rf build

echo "Done! Generated ${DMG_NAME}"
