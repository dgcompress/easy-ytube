#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="EasyYtube"
DMG_NAME="${APP_NAME}.dmg"
STAGING=".dmg-staging"

if [ ! -d "${APP_NAME}.app" ]; then
    echo "== ${APP_NAME}.app non trovata, la costruisco prima =="
    ./build.sh
fi

echo "== Preparazione DMG =="
rm -rf "$STAGING" "$DMG_NAME"
mkdir -p "$STAGING"
cp -R "${APP_NAME}.app" "$STAGING/${APP_NAME}.app"
ln -s /Applications "$STAGING/Applications"

hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -ov -format UDZO "$DMG_NAME"
rm -rf "$STAGING"

echo "== Done: $DMG_NAME =="
