#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="EasyYtube"
BUNDLE_ID="com.gabrielsturzu.easyytube"
VERSION="${YTUNE_VERSION:-1.0.0}"
PKG_NAME="${APP_NAME} Installer.pkg"
STAGING=".pkg-staging"

if [ ! -d "${APP_NAME}.app" ]; then
    echo "== ${APP_NAME}.app non trovata, la costruisco prima =="
    ./build.sh
fi

echo "== Preparazione Installer.pkg =="
rm -rf "$STAGING" "$PKG_NAME"
mkdir -p "$STAGING"
cp -R "${APP_NAME}.app" "$STAGING/${APP_NAME}.app"

pkgbuild \
    --root "$STAGING" \
    --identifier "$BUNDLE_ID" \
    --version "$VERSION" \
    --install-location /Applications \
    "$PKG_NAME"

rm -rf "$STAGING"

echo "== Done: $PKG_NAME =="
