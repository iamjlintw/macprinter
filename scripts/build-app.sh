#!/bin/bash
# 建置 macprinter.app（universal：arm64＋x86_64）、ad-hoc 簽章，並打包成 .dmg。
# 用法：scripts/build-app.sh [--install] [版本號]
#   產出只有 build/macprinter-<版本號>.dmg；組裝 .app 的暫存資料夾用完即刪，
#   避免「應用程式」以外多一份 macprinter.app。
#   --install：另外用新版覆蓋 /Applications/macprinter.app（會先關掉執行中的 App）。
set -euo pipefail

INSTALL=false
if [ "${1:-}" = "--install" ]; then
  INSTALL=true
  shift
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-0.1.0}"
BUILD_NUMBER="$(git -C "$ROOT" rev-list --count HEAD 2>/dev/null || echo 1)"
OUT="$ROOT/build"
BUNDLE_ID="io.github.iamjlintw.macprinter"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

STAGE="$(mktemp -d)"
APP="$STAGE/macprinter.app"
cleanup() {
  [ -d "$APP" ] && "$LSREGISTER" -u "$APP" 2>/dev/null || true
  rm -rf "$STAGE"
}
trap cleanup EXIT

cd "$ROOT"
swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"

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
mkdir -p "$OUT"
ln -s /Applications "$STAGE/Applications"
rm -f "$OUT/macprinter-$VERSION.dmg"
hdiutil create -quiet -volname "macprinter $VERSION" -srcfolder "$STAGE" -format UDZO "$OUT/macprinter-$VERSION.dmg"
echo "DMG：$OUT/macprinter-$VERSION.dmg"

if $INSTALL; then
  osascript -e "tell application id \"$BUNDLE_ID\" to quit" 2>/dev/null || true
  for _ in $(seq 1 10); do
    pgrep -f "/Applications/macprinter.app/Contents/MacOS/macprinter$" >/dev/null || break
    sleep 0.5
  done
  rm -rf /Applications/macprinter.app
  ditto "$APP" /Applications/macprinter.app
  "$LSREGISTER" -f /Applications/macprinter.app
  echo "已更新：/Applications/macprinter.app"
fi
