#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="EasyYtube"
BUNDLE_ID="com.gabrielsturzu.easyytube"
VERSION="${YTUNE_VERSION:-1.0.0}"
BUILD_DIR=".build/release"
APP_DIR="${APP_NAME}.app"

echo "== Building Swift executable (release) =="
swift build -c release

echo "== Assembling ${APP_DIR} =="
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources/bin"

cp "$BUILD_DIR/${APP_NAME}" "$APP_DIR/Contents/MacOS/${APP_NAME}"
cp "Resources/bin/yt-dlp" "$APP_DIR/Contents/Resources/bin/yt-dlp"
cp "Resources/bin/ffmpeg" "$APP_DIR/Contents/Resources/bin/ffmpeg"
cp "Resources/bin/deno" "$APP_DIR/Contents/Resources/bin/deno"
chmod +x "$APP_DIR/Contents/Resources/bin/yt-dlp" "$APP_DIR/Contents/Resources/bin/ffmpeg" "$APP_DIR/Contents/Resources/bin/deno"

if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

if [ -d "Localization/en.lproj" ]; then
    mkdir -p "$APP_DIR/Contents/Resources/en.lproj"
    cp Localization/en.lproj/*.strings "$APP_DIR/Contents/Resources/en.lproj/"
fi

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.music</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>it</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>it</string>
        <string>en</string>
    </array>
$( [ -f "Resources/AppIcon.icns" ] && echo "    <key>CFBundleIconFile</key>
    <string>AppIcon</string>" )
</dict>
</plist>
PLIST

echo "== Ad-hoc code signing =="
codesign --force --deep --sign - "$APP_DIR"

echo "== Done: $APP_DIR =="
