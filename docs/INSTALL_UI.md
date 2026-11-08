# 安裝／系統設定 UI

## 已納入產品打包流程的改善

| 問題 | 原因 | 產品作法 |
|------|------|----------|
| 「速」圖示／授權 | 不宜散佈 Apple TCIM `sucheng.tiff` | **自產**灰底白字「速」TIFF／icns（`prepare_icons.sh`）；`TISIconIsTemplate=false` |
| 已安裝列表藍塊大圖 | 舊 `Assets.car` 內 舊上游 Assets 圖示 | **刪除 Assets.car**；以 `Rime.tiff`（自產速成圖）滿足引擎 `NSImage(named:"Rime")`；menu → `sucheng.tiff` |
| 設定頁右側空白（無鍵盤） | 第三方 IM 預設不帶 `Preferences.prefPane` | 打包嵌入 `Resources/Preferences.prefPane`，顯示速成字根鍵盤圖 |
| 「加入輸入法」Keyboard layout not available | 原機走私有 `TextInput_zh`／`KeyboardLayouts` Artwork | **系統限制**，無法掛上；改在已安裝設定頁與 `keyboard_preview.png` 提供 |
| Info.plist 損壞 | PlistBuddy 鍵名黏連 | `plistlib` 整段寫入 |
| 未簽名被殺（exit 137） | Gatekeeper | `codesign --sign -` |
| 建置不自包含 | 必須碰巧已安裝引擎 | 優先 `vendor/engine/`（`vendor_engine.sh`）或 `ASC_ENGINE_APP` |

打包指令：

```bash
bash packaging/scripts/vendor_engine.sh    # 首次：快取基底引擎（gitignore）
bash packaging/scripts/build_preview_app.sh
bash packaging/scripts/install_preview.sh  # 溫和安裝；圖示卡住再加 --hard
```

樣式對齊原機 TCIM 速成：

- `tsInputModeScriptKey = smTradChinese`
- `TISIconLabels.Primary = 速`
- `tsInputModeKeyEquivalentKey = S`
- 選單圖：灰底圓角 + 白「速」

## Keyboard 預覽

| 位置 | 原機 | 蘋果速成 |
|------|------|----------|
| 加入輸入法對話框下方 | 有（私有 Artwork） | 系統限制，仍會顯示 *not available* |
| 已安裝輸入法右側面板 | 有偏好設定／鍵盤 | **`Preferences.prefPane` 顯示速成字根鍵盤** |
| 實際打字 | 字根 | preedit「日月金木…」 |

## 圖示／鍵盤驗收

1. 系統設定 → 鍵盤 → 輸入法 → ＋：Apple SuCheng 左側為**灰底白字「速」**  
2. 已加入列表選中後，右側應出現鍵盤預覽（不再是空白＋僅警告）  
3. 若快取未刷新：`bash packaging/scripts/install_preview.sh --hard`，或登出再登入  
