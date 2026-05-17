#!/bin/bash
set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="CameraApp"
SCHEME="CameraApp"
PROJECT="$PROJECT_DIR/$APP_NAME.xcodeproj"
BUILD_DIR="$PROJECT_DIR/build"
DERIVED_DATA="$BUILD_DIR/DerivedData"
ARCHIVE_PATH="$BUILD_DIR/$APP_NAME.xcarchive"
RELEASE_DIR="$BUILD_DIR/release"

# Codesign / notary (disabled by default)
ENABLE_CODESIGN="${ENABLE_CODESIGN:-false}"
DEVELOPER_ID="${DEVELOPER_ID:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PROJECT_DIR/$APP_NAME/Info.plist")
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$PROJECT_DIR/$APP_NAME/Info.plist")
ZIP_NAME="MacMonitor-v${VERSION}-macOS.zip"

# ─── Validation ──────────────────────────────────────────────────
if [ "$ENABLE_CODESIGN" = "true" ] && [ -z "$DEVELOPER_ID" ]; then
    echo "ERROR: ENABLE_CODESIGN=true but DEVELOPER_ID is not set."
    echo "       Set DEVELOPER_ID to your signing identity (e.g., 'Developer ID Application: Name (TEAMID)')."
    exit 1
fi

# ─── Clean ───────────────────────────────────────────────────────
echo "==> Cleaning previous build..."
rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

# ─── Archive ─────────────────────────────────────────────────────
echo "==> Archiving $APP_NAME v$VERSION..."
xcodebuild -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$DERIVED_DATA" \
    -archivePath "$ARCHIVE_PATH" \
    archive

# ─── Copy app ────────────────────────────────────────────────────
APP_PATH="$ARCHIVE_PATH/Products/Applications/$APP_NAME.app"
if [ ! -d "$APP_PATH" ]; then
    echo "ERROR: Archive did not produce $APP_NAME.app"
    exit 1
fi

echo "==> Copying app to release directory..."
cp -R "$APP_PATH" "$RELEASE_DIR/$APP_NAME.app"

# ─── Codesign (optional) ────────────────────────────────────────
if [ "$ENABLE_CODESIGN" = "true" ]; then
    echo "==> Signing with $DEVELOPER_ID..."
    codesign --force --deep --sign "$DEVELOPER_ID" \
        --options runtime \
        --timestamp \
        "$RELEASE_DIR/$APP_NAME.app"
fi

# ─── Zip ─────────────────────────────────────────────────────────
echo "==> Creating $ZIP_NAME..."
(cd "$RELEASE_DIR" && zip -r -y "$ZIP_NAME" "$APP_NAME.app")

# ─── Summary ─────────────────────────────────────────────────────
echo ""
echo "==> Build complete!"
echo "    Version:  $VERSION"
echo "    Bundle ID: $BUNDLE_ID"
echo "    App:      $RELEASE_DIR/$APP_NAME.app"
echo "    Zip:      $RELEASE_DIR/$ZIP_NAME"
echo ""
echo "    To run:"
echo "    open '$RELEASE_DIR/$APP_NAME.app'"
