#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

echo "=========================================="
echo "🚀 Building CalBar.app and Distribution DMG"
echo "=========================================="

# 1. Build and verify app bundle
./scripts/build_app.sh

# 2. Ensure background image exists
if [ ! -f "dmg_background.png" ]; then
    swift scripts/generate_dmg_background.swift
fi

# 3. Clean previous artifacts
DMG_NAME="CalBar"
FINAL_DMG="${DMG_NAME}.dmg"
TEMP_DMG="${DMG_NAME}_temp.dmg"
STAGING_DIR="dist/dmg_staging"

rm -f "${FINAL_DMG}" "${TEMP_DMG}"
rm -rf "dist"
mkdir -p "${STAGING_DIR}/.background"

echo "📦 Preparing DMG staging volume..."
cp -R "CalBar.app" "${STAGING_DIR}/"
ln -s /Applications "${STAGING_DIR}/Applications"
cp "AppIcon.icns" "${STAGING_DIR}/.VolumeIcon.icns"
cp "dmg_background.png" "${STAGING_DIR}/.background/background.png"

# Set volume icon attributes
SetFile -c icnC "${STAGING_DIR}/.VolumeIcon.icns" 2>/dev/null || true
SetFile -a C "${STAGING_DIR}" 2>/dev/null || true

echo "💿 Creating temporary writable disk image..."
hdiutil create \
    -srcfolder "${STAGING_DIR}" \
    -volname "${DMG_NAME}" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDRW \
    -size 80m \
    "${TEMP_DMG}"

echo "🖥️ Mounting temporary image for Finder styling..."
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "${TEMP_DMG}" | grep -E '^/dev/' | head -n 1 | awk '{print $1}')
sleep 2

# Mount point is /Volumes/CalBar
VOLUME_PATH="/Volumes/${DMG_NAME}"

if [ -d "${VOLUME_PATH}" ]; then
    echo "🎨 Applying Finder visual layout (icon positioning & background)..."
    osascript << EOF || true
tell application "Finder"
    tell disk "${DMG_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {300, 150, 900, 550}
        set viewOptions to the icon view options of container window
        set icon size of viewOptions to 112
        set arrangement of viewOptions to not arranged
        try
            set background picture of viewOptions to file ".background:background.png"
        end try
        set position of item "CalBar.app" of container window to {160, 205}
        set position of item "Applications" of container window to {440, 205}
        close
        open
        update without registering applications
        delay 1
    end tell
end tell
EOF

    SetFile -a C "${VOLUME_PATH}" 2>/dev/null || true
    sync
    echo "🔒 Unmounting temporary disk image..."
    hdiutil detach "${DEVICE}" || hdiutil detach "${VOLUME_PATH}" -force
else
    echo "⚠️ Mounted volume not found at ${VOLUME_PATH}, detaching device..."
    hdiutil detach "${DEVICE}" -force || true
fi

echo "🗜️ Compressing into release DMG: ${FINAL_DMG}..."
hdiutil convert "${TEMP_DMG}" -format UDZO -imagekey zlib-level=9 -o "${FINAL_DMG}"
rm -f "${TEMP_DMG}"
rm -rf "dist"

echo "🔏 Signing DMG..."
codesign --force --sign - "${FINAL_DMG}" 2>/dev/null || true

echo "=========================================="
echo "🎉 SUCCESS: ${FINAL_DMG} is ready!"
echo "File: $(pwd)/${FINAL_DMG} ($(du -h "${FINAL_DMG}" | awk '{print $1}'))"
echo "=========================================="
