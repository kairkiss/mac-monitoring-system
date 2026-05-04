#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="CameraApp"
BUILD_DIR="$PROJECT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "==> Building $APP_NAME..."
xcodebuild -project "$PROJECT_DIR/$APP_NAME.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    build

echo "==> Creating app bundle..."
EXEC_PATH=$(find "$BUILD_DIR/DerivedData" -name "$APP_NAME" -type f -path "*/Release/*" | head -1)
if [ -z "$EXEC_PATH" ]; then
    echo "ERROR: Could not find built executable"
    exit 1
fi

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$EXEC_PATH" "$APP_BUNDLE/Contents/MacOS/"
cp "$PROJECT_DIR/$APP_NAME/Info.plist" "$APP_BUNDLE/Contents/"

echo ""
echo "==> Build complete!"
echo "    App bundle: $APP_BUNDLE"
echo ""
echo "    To run:"
echo "    open '$APP_BUNDLE'"
echo ""
echo "    To run from Xcode:"
echo "    open '$PROJECT_DIR/$APP_NAME.xcodeproj'"
