# 品牌對照

| 位置 | 內容 | 現況 |
|------|------|------|
| 顯示名 | InfoPlist.strings / xcstrings | 蘋果速成 / Apple SuCheng |
| Bundle ID | Info.plist | `com.applesucheng.inputmethod.SuCheng` |
| 模式 ID | Info.plist | `com.applesucheng.inputmethod.SuCheng.Hant` |
| Controller | Info.plist | `AppleSuCheng.AppleSuChengInputController` |
| Connection | Info.plist | `AppleSuCheng_Connection` |
| 主題檔 | SharedSupport | `applesucheng.yaml` |
| 選單／Fn 圖示 | sucheng.tiff | 自產灰階 template，「速」 |
| 使用者資料 | `~/Library/AppleSuCheng` | 階段 B |

打包請走 `packaging/scripts/build_preview_app.sh`，勿只靠裸 Xcode 產物當發行包。
