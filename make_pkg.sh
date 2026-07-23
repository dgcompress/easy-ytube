#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="EasyYtube"
BUNDLE_ID="com.gabrielsturzu.easyytube"
VERSION="${YTUNE_VERSION:-1.0.0}"
PKG_NAME="${APP_NAME} Installer.pkg"
STAGING=".pkg-staging"
COMPONENT_PLIST=".pkg-component.plist"

if [ ! -d "${APP_NAME}.app" ]; then
    echo "== ${APP_NAME}.app non trovata, la costruisco prima =="
    ./build.sh
fi

echo "== Preparazione Installer.pkg =="
rm -rf "$STAGING" "$PKG_NAME" "$COMPONENT_PLIST"
mkdir -p "$STAGING"
cp -R "${APP_NAME}.app" "$STAGING/${APP_NAME}.app"

# pkgbuild marks bundles as relocatable by default: if a bundle with the same
# identifier is already registered with Launch Services anywhere on disk (e.g.
# a dev copy that was opened directly), the installer silently installs THERE
# instead of --install-location. Forcing BundleIsRelocatable=false makes it
# always install to /Applications as intended.
pkgbuild --analyze --root "$STAGING" "$COMPONENT_PLIST"
/usr/libexec/PlistBuddy -c "Set :0:BundleIsRelocatable false" "$COMPONENT_PLIST"

pkgbuild \
    --root "$STAGING" \
    --identifier "$BUNDLE_ID" \
    --version "$VERSION" \
    --install-location /Applications \
    --component-plist "$COMPONENT_PLIST" \
    "$PKG_NAME"

rm -rf "$STAGING" "$COMPONENT_PLIST"

echo "== Done: $PKG_NAME =="
