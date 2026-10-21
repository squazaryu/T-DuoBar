#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="1.12.0"
BUILD_NUMBER="36"
BUILD_DIR="${TMPDIR:-/tmp}/T-DuoBar-Package-DerivedData"
OUTPUT_DIR="$ROOT_DIR/build/releases/$VERSION"
DMG="$OUTPUT_DIR/T-DuoBar-$VERSION.dmg"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

if [[ -e "$DMG" ]]; then
    echo "Output already exists: $DMG. Move it aside before rebuilding." >&2
    exit 1
fi
mkdir -p "$OUTPUT_DIR"
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/T-DuoBar-DMG.XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT

xcodebuild -quiet -project "$ROOT_DIR/DuoBar.xcodeproj" -scheme DuoBar \
    -configuration Release -destination 'generic/platform=macOS' \
    -derivedDataPath "$BUILD_DIR" ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
    CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= \
    MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD_NUMBER" build
APP="$BUILD_DIR/Build/Products/Release/DuoBar.app"
codesign --verify --deep --strict "$APP"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")" == "$VERSION" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Contents/Info.plist")" == "$BUILD_NUMBER" ]]
ARCHITECTURES="$(/usr/bin/lipo -archs "$APP/Contents/MacOS/DuoBar")"
[[ " $ARCHITECTURES " == *" arm64 "* && " $ARCHITECTURES " == *" x86_64 "* ]]

ditto "$APP" "$STAGING_DIR/DuoBar.app"
codesign --verify --deep --strict "$STAGING_DIR/DuoBar.app"
ln -s /Applications "$STAGING_DIR/Applications"
cp "$ROOT_DIR/LICENSE" "$STAGING_DIR/LICENSE.txt"
cat > "$STAGING_DIR/READ ME FIRST.txt" <<'NOTICE'
T-DuoBar 1.12.0 — experimental community build

This app has an ad-hoc signature. It is NOT Developer ID signed or Apple notarized.
This differs from the signed releases of the original DuoBar project.

Installation:
1. Quit DuoBar if it is running.
2. Keep a backup of your existing DuoBar.app, then drag DuoBar.app to Applications.
3. Launch it from Applications. Its icon appears in the menu bar; it has no Dock window.

The app retains the DuoBar.app filename and bundle identifier, so it replaces the installed
DuoBar and shares its preferences. Do not run both copies simultaneously.

macOS may block an Internet-downloaded copy. If you trust this release and have checked
its SHA-256, follow Apple's documented Privacy & Security procedure:
https://support.apple.com/en-us/102445
Do not disable Gatekeeper or SIP globally.

Accessory readings depend on macOS/device support. The charge-limit readout is unavailable.

Исходники и ограничения / Source and limitations:
https://github.com/squazaryu/T-DuoBar

Эта сборка не имеет Developer ID и notarization. Сначала завершите DuoBar и сохраните
предыдущую копию. Перетащите DuoBar.app в Applications и запускайте оттуда.
Приложение работает через значок в строке меню. Защита macOS может потребовать
индивидуального разрешения в системных настройках безопасности; инструкция Apple — выше.
NOTICE
hdiutil create -quiet -volname "T-DuoBar $VERSION" -srcfolder "$STAGING_DIR" -format UDZO -ov "$DMG"
hdiutil verify "$DMG"
(cd "$OUTPUT_DIR" && shasum -a 256 "T-DuoBar-$VERSION.dmg" > SHA256SUMS)
printf 'DMG: %s\nChecksum: %s\n' "$DMG" "$OUTPUT_DIR/SHA256SUMS"
