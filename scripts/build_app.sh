#!/usr/bin/env bash
set -e

echo "🔨 Building CalBar in release mode..."
swift build -c release

APP_NAME="CalBar"
BUILD_DIR=".build/release"
APP_DIR="${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "📦 Packaging ${APP_NAME}.app..."
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

cp "${BUILD_DIR}/${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"

if [ ! -f "AppIcon.icns" ]; then
    ./scripts/build_icon.sh
fi
cp "AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"

cat << 'EOF' > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>CalBar</string>
    <key>CFBundleIdentifier</key>
    <string>com.michaelbrancazio.CalBar</string>
    <key>CFBundleName</key>
    <string>CalBar</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSCalendarsUsageDescription</key>
    <string>CalBar needs access to your calendars to display your Google and system events in the menu bar.</string>
    <key>NSCalendarsFullAccessUsageDescription</key>
    <string>CalBar needs full access to your calendars to display and sync events in the menu bar.</string>
</dict>
</plist>
EOF

echo "🔏 Signing ${APP_DIR}..."
codesign --force --deep --sign - -r='designated => identifier "com.michaelbrancazio.CalBar"' "${APP_DIR}"

echo "✅ Successfully built and signed ${APP_DIR}!"
echo "To run: open ${APP_DIR}"
