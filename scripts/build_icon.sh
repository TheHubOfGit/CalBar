#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

echo "🎨 Generating master AppIcon..."
swift scripts/generate_icon.swift

echo "📐 Rendering all Retina resolutions into AppIcon.iconset..."
rm -rf AppIcon.iconset
mkdir -p AppIcon.iconset

sips -z 16 16     AppIcon_1024.png --out AppIcon.iconset/icon_16x16.png > /dev/null
sips -z 32 32     AppIcon_1024.png --out AppIcon.iconset/icon_16x16@2x.png > /dev/null
sips -z 32 32     AppIcon_1024.png --out AppIcon.iconset/icon_32x32.png > /dev/null
sips -z 64 64     AppIcon_1024.png --out AppIcon.iconset/icon_32x32@2x.png > /dev/null
sips -z 128 128   AppIcon_1024.png --out AppIcon.iconset/icon_128x128.png > /dev/null
sips -z 256 256   AppIcon_1024.png --out AppIcon.iconset/icon_128x128@2x.png > /dev/null
sips -z 256 256   AppIcon_1024.png --out AppIcon.iconset/icon_256x256.png > /dev/null
sips -z 512 512   AppIcon_1024.png --out AppIcon.iconset/icon_256x256@2x.png > /dev/null
sips -z 512 512   AppIcon_1024.png --out AppIcon.iconset/icon_512x512.png > /dev/null
sips -z 1024 1024 AppIcon_1024.png --out AppIcon.iconset/icon_512x512@2x.png > /dev/null

echo "🔨 Compiling AppIcon.icns with iconutil..."
iconutil -c icns AppIcon.iconset -o AppIcon.icns
rm -rf AppIcon.iconset

echo "✅ AppIcon.icns successfully built!"
