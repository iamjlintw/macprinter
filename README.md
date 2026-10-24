# macprinter

在 macOS 上多一台「**存成圖片**」印表機：任何 App 按 ⌘P 選它列印，每一頁都會直接存成 PNG，不用再手動轉檔。
用起來就像 Windows 上的 PDFCreator、PDF24 這類虛擬印表機。

- 輸出：PNG、300 dpi、彩色、白底、每頁一張（A4 一頁 2480×3508 像素）
- 紙張：預設 A4，可在列印對話框改成 A3、A5、JIS B4、JIS B5、Letter、Legal
- 轉檔使用 macOS 內建的 CoreGraphics，不需要另外安裝 Ghostscript 或 poppler
- 這台 Mac 的所有帳號都能使用，各帳號的輸出彼此分開
- 支援 macOS 13 Ventura 以上（目前只在 macOS 26 實測）

## 安裝

1. 到 [Releases](https://github.com/iamjlintw/macprinter/releases) 下載 `macprinter-<版本>.dmg`，把 `macprinter.app` 拖到「應用程式」資料夾。
2. 第一次打開：本 App 沒有 Apple Developer ID 簽章，macOS 會擋下來。
   請到「系統設定 ▸ 隱私權與安全性」，在下方找到 macprinter，按「強制打開」或「仍要打開」。
3. 在 App 裡按「**安裝印表機**」，輸入系統管理員密碼。
4. 出現「允許通知」的詢問時請按允許，列印完成或失敗時才看得到通知。

> 請先把 App 放到「應用程式」再按安裝。背景程式會記住 App 的位置，之後搬動 App 要重新按一次「重新安裝」。

## 使用

1. 在任何 App 按 ⌘P，印表機選「存成圖片」，按「列印」。
2. 完成後會跳出通知，點通知會在 Finder 選取產生的圖片。

輸出位置：

- 預設：`/Users/Shared/macprinter/<帳號>/`，只有該帳號讀得到。
- 自訂：在 App 的「輸出資料夾」按「變更…」。列印完成後由背景程式搬過去；資料夾寫不進去時會留在預設資料夾，並在通知裡說明。

檔名：`<文件標題>_<yyyyMMdd-HHmmss>_p<頁碼>.png`，例如 `報表_20261024-104200_p01.png`。

- 頁碼依總頁數補零，最少兩位（100 頁以上變成 `p001`）。
- 標題裡的 `/`、`:` 等字元換成 `_`；沒有標題時用「未命名」。
- 同名時在時間戳記後加 `-2`、`-3`…。
- 轉檔失敗時改為保留原始 PDF（`<文件標題>_<時間戳記>.pdf`），並發通知。

## 移除

在 App 按「移除印表機」。已產生的圖片不會刪除，留在原本的資料夾。

也可以在終端機執行：

```sh
sudo /Applications/macprinter.app/Contents/Resources/uninstall.sh
```

## 疑難排解

- App 的「查看記錄」顯示最近 24 小時的記錄。也可以在終端機查：
  ```sh
  log show --last 1h --style compact --predicate 'subsystem == "io.github.iamjlintw.macprinter"'
  ```
- 記錄不包含文件內容；文件標題以 private 欄位記錄，預設會顯示成 `<private>`。

## 從原始碼建置

需要 Xcode 15 以上（Swift 5.9）。

```sh
swift test                            # 單元測試
scripts/build-app.sh 0.1.0            # 只產出 build/macprinter-0.1.0.dmg
scripts/build-app.sh --install 0.1.0  # 另外用新版覆蓋 /Applications/macprinter.app
```

建置時組裝 `.app` 的暫存資料夾用完就刪掉，`build/` 裡只留 `.dmg`，系統裡只會有「應用程式」那一份 macprinter。

## 運作方式

| 元件 | 位置 | 說明 |
|---|---|---|
| CUPS 後端 | `/usr/libexec/cups/backend/macprinter` | 收到 PDF 後轉成 PNG，寫進 `/Users/Shared/macprinter/<帳號>/`，再留一份工作清單 |
| 印表機佇列 | `macprinter`（顯示名稱「存成圖片」） | device URI `macprinter:/`，不分享到網路 |
| 背景程式 | `/Library/LaunchAgents/io.github.iamjlintw.macprinter.agent.plist` | 每個帳號登入後各自執行；依工作清單把圖片搬到自訂資料夾並發通知 |

CUPS 後端在沙盒裡執行，寫不進使用者的家目錄，所以搬到自訂資料夾的工作交給以使用者身分執行的背景程式。
後端以 root 執行，寫入使用者資料夾時會先把權限降成該帳號。

## 已知限制

- 沒有 Developer ID 簽章，第一次打開需要手動允許（見「安裝」）。
- 每次重新建置的 ad-hoc 簽章都不同；自訂資料夾在「桌面」「文件」時，macOS 可能會再問一次存取權限。
- 帳號沒有登入時背景程式不會執行，圖片會先留在預設資料夾，下次登入時才搬。

## 授權

[MIT](LICENSE)
