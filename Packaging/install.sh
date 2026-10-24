#!/bin/bash
# 安裝「存成圖片」印表機。需要 root 權限。
# 用法：sudo install.sh <macprinter.app 路徑> [呼叫者 UID]
# App 會透過系統管理員密碼對話框呼叫本腳本；也可以在終端機用 sudo 直接執行。
set -euo pipefail
trap 'echo "安裝失敗：install.sh 第 $LINENO 行（代碼 $?）：$BASH_COMMAND" >&2' ERR

QUEUE="macprinter"
DISPLAY_NAME="存成圖片"
BACKEND="/usr/libexec/cups/backend/macprinter"
SPOOL="/Users/Shared/macprinter"
LABEL="io.github.iamjlintw.macprinter.agent"
AGENT_PLIST="/Library/LaunchAgents/${LABEL}.plist"

[ "$(id -u)" = 0 ] || { echo "請用 sudo 執行" >&2; exit 1; }
APP="${1:?需要 macprinter.app 的路徑}"
CALLER_UID="${2:-${SUDO_UID:-}}"
APP="$(cd "$APP" && pwd -P)"

BACKEND_SRC="$APP/Contents/MacOS/macprinter-backend"
AGENT_BIN="$APP/Contents/MacOS/macprinter"
PPD="$APP/Contents/Resources/macprinter.ppd"
for f in "$BACKEND_SRC" "$AGENT_BIN" "$PPD"; do
  [ -f "$f" ] || { echo "找不到 $f" >&2; exit 1; }
done
if [ -n "$CALLER_UID" ] && ! [[ "$CALLER_UID" =~ ^[0-9]+$ ]]; then
  echo "UID 格式不正確：$CALLER_UID" >&2; exit 1
fi

# 1. CUPS 後端：root 0700，CUPS 才會以 root 執行
install -o root -g wheel -m 0700 "$BACKEND_SRC" "$BACKEND"

# 2. 印表機佇列：不分享到網路；後端出錯只取消該工作，不暫停印表機
lpadmin -p "$QUEUE" -E -v "${QUEUE}:/" -P "$PPD" -D "$DISPLAY_NAME" -L "" \
  -o printer-is-shared=false -o printer-error-policy=abort-job

# 3. 輸出資料夾：上層 root 0711（別人列不出有哪些帳號），trigger 檔所有人可讀
mkdir -p "$SPOOL"
chown root:wheel "$SPOOL"
chmod 0711 "$SPOOL"
touch "$SPOOL/.trigger"
chown root:wheel "$SPOOL/.trigger"
chmod 0644 "$SPOOL/.trigger"
if [ -n "$CALLER_UID" ]; then
  CALLER="$(id -un "$CALLER_UID")"
  mkdir -p "$SPOOL/$CALLER"
  chown "$CALLER_UID:$(id -g "$CALLER_UID")" "$SPOOL/$CALLER"
  chmod 0700 "$SPOOL/$CALLER"
fi

# 4. 背景程式：每個帳號登入後各自執行，trigger 更新時喚起
TMP_PLIST="$(mktemp)"
plutil -create xml1 "$TMP_PLIST"
plutil -insert Label -string "$LABEL" "$TMP_PLIST"
plutil -insert ProgramArguments -array "$TMP_PLIST"
plutil -insert ProgramArguments -string "$AGENT_BIN" -append "$TMP_PLIST"
plutil -insert ProgramArguments -string "--agent" -append "$TMP_PLIST"
plutil -insert WatchPaths -array "$TMP_PLIST"
plutil -insert WatchPaths -string "$SPOOL/.trigger" -append "$TMP_PLIST"
plutil -insert RunAtLoad -bool true "$TMP_PLIST"
plutil -insert ProcessType -string "Background" "$TMP_PLIST"
plutil -insert LimitLoadToSessionType -string "Aqua" "$TMP_PLIST"
install -o root -g wheel -m 0644 "$TMP_PLIST" "$AGENT_PLIST"
rm -f "$TMP_PLIST"

if [ -n "$CALLER_UID" ]; then
  launchctl bootout "gui/$CALLER_UID/$LABEL" 2>/dev/null || true
  launchctl bootstrap "gui/$CALLER_UID" "$AGENT_PLIST"
fi

echo "已安裝「$DISPLAY_NAME」印表機"
