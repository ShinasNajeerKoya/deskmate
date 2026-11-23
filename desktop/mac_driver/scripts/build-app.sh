#!/bin/bash
# Builds "Deskmate Hub.app" (universal: Apple silicon + Intel) and a zip for releases.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Sources/DeskmateHub/Info.plist)
swift build -c release --arch arm64 --arch x86_64
BIN_DIR=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)

APP="dist/Deskmate Hub.app"
rm -rf dist
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/DeskmateHub" "$APP/Contents/MacOS/DeskmateHub"
cp Sources/DeskmateHub/Info.plist "$APP/Contents/Info.plist"

# Ad-hoc signature (no Apple Developer account): macOS asks to confirm on first open.
codesign --force --deep --sign - "$APP"

(cd dist && ditto -c -k --keepParent "Deskmate Hub.app" "DeskmateHub-macOS-$VERSION.zip")
echo "Built dist/Deskmate Hub.app and dist/DeskmateHub-macOS-$VERSION.zip"
