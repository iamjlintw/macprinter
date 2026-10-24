#!/bin/bash
# 建置 macprinter.app（universal：arm64＋x86_64）、ad-hoc 簽章，並打包成 .dmg。
# 用法：scripts/build-app.sh [版本號]，產出在 build/
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-0.1.0}"
BUILD_NUMBER="$(git -C "$ROOT" rev-list --count HEAD 2>/dev/null || echo 1)"
OUT="$ROOT/build"
APP="$OUT/macprinter.app"

cd "$ROOT"
swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/macprinter" "$APP/Contents/MacOS/macprinter"
cp "$BIN/macprinter-backend" "$APP/Contents/MacOS/macprinter-backend"
cp Packaging/macprinter.ppd Packaging/install.sh Packaging/uninstall.sh "$APP/Contents/Resources/"
chmod 0755 "$APP/Contents/Resources/install.sh" "$APP/Contents/Resources/uninstall.sh"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD_NUMBER/" Packaging/Info.plist > "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist" >/dev/null

# ad-hoc 簽章：先簽內層的後端，再簽整個 App
codesign --force --sign - --timestamp=none "$APP/Contents/MacOS/macprinter-backend"
codesign --force --sign - --timestamp=none "$APP"
codesign --verify --strict "$APP"

# .dmg：App＋「應用程式」捷徑
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$OUT/macprinter-$VERSION.dmg"
hdiutil create -quiet -volname "macprinter $VERSION" -srcfolder "$STAGE" -format UDZO "$OUT/macprinter-$VERSION.dmg"
rm -rf "$STAGE"

echo "App：$APP"
echo "DMG：$OUT/macprinter-$VERSION.dmg"
