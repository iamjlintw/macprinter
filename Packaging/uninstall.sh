#!/bin/bash
# 移除「存成圖片」印表機。需要 root 權限。
# 用法：sudo uninstall.sh
# 已產生的圖片（/Users/Shared/macprinter/<帳號>/）不會刪除。
set -euo pipefail

QUEUE="macprinter"
BACKEND="/usr/libexec/cups/backend/macprinter"
SPOOL="/Users/Shared/macprinter"
LABEL="io.github.iamjlintw.macprinter.agent"
AGENT_PLIST="/Library/LaunchAgents/${LABEL}.plist"

[ "$(id -u)" = 0 ] || { echo "請用 sudo 執行" >&2; exit 1; }

if lpstat -p "$QUEUE" >/dev/null 2>&1; then
  lpadmin -x "$QUEUE"
fi
rm -f "$BACKEND"

# 所有已登入帳號的背景程式都停掉
for uid in $(dscl . -list /Users UniqueID | awk '$2 >= 500 {print $2}'); do
  launchctl bootout "gui/$uid/$LABEL" 2>/dev/null || true
done
rm -f "$AGENT_PLIST"

# 只清掉交接用的檔案，圖片保留
rm -f "$SPOOL/.trigger"
for inbox in "$SPOOL"/*/.inbox; do
  [ -d "$inbox" ] && rm -rf "$inbox"
done
# 資料夾全空時才刪掉
find "$SPOOL" -mindepth 1 -maxdepth 1 -type d -empty -delete 2>/dev/null || true
rmdir "$SPOOL" 2>/dev/null || true

echo "已移除「存成圖片」印表機"
[ -d "$SPOOL" ] && echo "已產生的圖片仍保留在 $SPOOL"
exit 0
