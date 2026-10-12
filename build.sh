#!/usr/bin/env bash
# ==============================================================================
# Sagaa Build & Package Script
# Production macOS build pipeline inspired by vorssaint-utils & Handy
# ==============================================================================
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Sagaa"
BUNDLE_ID="com.tklwin.sagaa"
BUILD_DIR="build"
DIST_DIR="dist"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
DMG_PATH="$DIST_DIR/$APP_NAME-macOS.dmg"

INSTALL=0
MAKE_DMG=0
CLEAN=0

for arg in "$@"; do
    case "$arg" in
        --install) INSTALL=1 ;;
        --dmg)     MAKE_DMG=1 ;;
        --clean)   CLEAN=1 ;;
        --help|-h)
            echo "Usage: ./build.sh [OPTIONS]"
            echo "Options:"
            echo "  --install   Install to /Applications/Sagaa.app"
            echo "  --dmg       Generate production distribution DMG in dist/"
            echo "  --clean     Clean all build and distribution artifacts"
            exit 0
            ;;
    esac
done

if (( CLEAN )); then
    echo "▸ Cleaning build artifacts..."
    rm -rf .build "$BUILD_DIR" "$DIST_DIR"
    echo "✓ Clean complete."
    exit 0
fi

echo "=========================================================="
echo "  🎙️  Building Sagaa - Offline Native Burmese ASR"
echo "=========================================================="

# 1. Compile CoreML model if necessary
if [[ ! -d "Models/BurmeseASR.mlmodelc" ]]; then
    echo "▸ Compiling CoreML model package..."
    if command -v xcrun &>/dev/null && xcrun --find coremlc &>/dev/null; then
        xcrun coremlc compile Models/BurmeseASR.mlpackage Models/
        echo "✓ Model compiled to Models/BurmeseASR.mlmodelc"
    else
        echo "⚠️ xcrun coremlc not found; looking for existing mlmodelc..."
    fi
fi

# 2. Build Swift executable
echo "▸ Compiling Swift binary in release mode..."
swift build -c release

# 3. Assemble .app bundle structure
echo "▸ Assembling $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

mkdir -p "$MACOS" "$RESOURCES"

# Copy binary
cp .build/release/Sagaa "$MACOS/Sagaa"
chmod +x "$MACOS/Sagaa"

# Copy resources
if [[ -d "Models/BurmeseASR.mlmodelc" ]]; then
    cp -R Models/BurmeseASR.mlmodelc "$RESOURCES/"
else
    echo "❌ Error: Models/BurmeseASR.mlmodelc missing!" >&2
    exit 1
fi

if [[ -f "Models/vocab.json" ]]; then
    cp Models/vocab.json "$RESOURCES/"
else
    echo "❌ Error: Models/vocab.json missing!" >&2
    exit 1
fi

# Copy AppIcon
if [[ -f "Resources/AppIcon.icns" ]]; then
    cp Resources/AppIcon.icns "$RESOURCES/"
fi

# Copy Info.plist
if [[ -f "Resources/Info.plist" ]]; then
    cp Resources/Info.plist "$CONTENTS/Info.plist"
else
    echo "❌ Error: Resources/Info.plist missing!" >&2
    exit 1
fi

# 4. Code Signing
SIGN_ID=$(security find-identity -v -p codesigning 2>/dev/null | grep -E "Apple Development|Developer ID Application" | head -n 1 | sed -E 's/.*"(.*)".*/\1/' || true)

if [[ -n "$SIGN_ID" ]]; then
    echo "▸ Signing app with identity: $SIGN_ID"
    codesign --force --deep --sign "$SIGN_ID" "$APP_BUNDLE"
else
    echo "▸ No developer identity found; signing ad-hoc (-)"
    codesign --force --deep --sign - "$APP_BUNDLE"
fi
echo "✓ App bundle assembled and signed successfully."

# 5. Install to /Applications if requested
if (( INSTALL )); then
    echo "▸ Installing $APP_NAME.app to /Applications..."
    # Close any running instance
    killall "$APP_NAME" 2>/dev/null || true
    rm -rf "/Applications/$APP_NAME.app"
    cp -R "$APP_BUNDLE" /Applications/
    echo "✓ Installed to /Applications/$APP_NAME.app"
fi

# 6. Create DMG if requested
if (( MAKE_DMG )); then
    echo "▸ Creating DMG package..."
    mkdir -p "$DIST_DIR"
    rm -f "$DMG_PATH"

    DMG_TMP="$(mktemp -d)"
    cp -R "$APP_BUNDLE" "$DMG_TMP/"
    ln -s /Applications "$DMG_TMP/Applications"

    hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_TMP" -ov -format UDZO "$DMG_PATH"
    rm -rf "$DMG_TMP"

    echo "✓ DMG created: $DMG_PATH"
    SHA256=$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')
    echo "ℹ DMG SHA256: $SHA256"
fi

echo "=========================================================="
echo "  ✅ Build complete!"
echo "=========================================================="

