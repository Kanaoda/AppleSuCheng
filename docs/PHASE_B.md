# 階段 B：自有前端

目標：從可編譯原始碼產出 `.app`（GPL fork，見 `frontend/UPSTREAM.md`），使用產品 Bundle ID／資料目錄／主題。

## 現況

| 項 | 值 |
|----|----|
| Bundle ID / TIS | `com.applesucheng.inputmethod.SuCheng` |
| 模式 ID | `com.applesucheng.inputmethod.SuCheng.Hant` |
| Controller | `AppleSuCheng.AppleSuChengInputController` |
| Connection | `AppleSuCheng_Connection` |
| 主題檔 | `applesucheng.yaml` |
| 使用者目錄 | `~/Library/AppleSuCheng` |
| Xcode 專案 | `frontend/AppleSuCheng.xcodeproj` |

## 建置

```bash
bash packaging/scripts/bootstrap_frontend.sh
bash packaging/scripts/build_frontend.sh
ASC_PHASE_B=1 bash packaging/scripts/build_preview_app.sh
bash packaging/scripts/install_preview.sh
```
