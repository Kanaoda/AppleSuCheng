# 安裝／系統設定 UI

| 項目 | 作法 |
|------|------|
| 「速」圖示 | 自產灰底白字 TIFF／icns（`prepare_icons.sh`），不散佈 Apple TCIM 圖檔 |
| 選單／Fn | `sucheng.tiff`；引擎 `NSImage(named:"Rime")` 用自產 `Rime.tiff` |
| 設定頁鍵盤圖 | 打包嵌入 `Preferences.prefPane` + `keyboard_preview.png` |
| 加入輸入法下方 Artwork | 系統私有限制，第三方無法掛上 |
| Gatekeeper | Release／安裝以 `codesign --sign -` ad-hoc 簽名 |

## 開發者本機

```bash
bash packaging/scripts/bootstrap_frontend.sh
bash packaging/scripts/build_frontend.sh
ASC_PHASE_B=1 bash packaging/scripts/build_preview_app.sh
bash packaging/scripts/install_preview.sh
```

## 一般用戶

下載 Release 的 `AppleSuCheng-*-macOS.zip` → 解壓 → 雙擊「安裝.command」。
