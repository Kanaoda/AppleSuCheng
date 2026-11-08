# 自有前端建置

| 項 | 值 |
|----|-----|
| Bundle ID / TIS | `com.applesucheng.inputmethod.SuCheng` |
| 模式 ID | `com.applesucheng.inputmethod.SuCheng.Hant` |
| Controller | `AppleSuCheng.AppleSuChengInputController` |
| 主題 | `applesucheng.yaml` |
| 使用者目錄 | `~/Library/AppleSuCheng` |
| Xcode | `frontend/AppleSuCheng.xcodeproj` |

```bash
bash packaging/scripts/bootstrap_frontend.sh
bash packaging/scripts/build_frontend.sh
ASC_PHASE_B=1 bash packaging/scripts/build_preview_app.sh
bash packaging/scripts/make_release.sh
```
