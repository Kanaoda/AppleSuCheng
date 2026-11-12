# 蘋果速成｜驗收校對清單

## 顯示與安裝

- [ ] 系統設定 → 鍵盤 → 輸入法 可見 **「蘋果速成」／Apple SuCheng**（不是生 Bundle ID；不要兩行同名）
- [ ] 選單列／輸入法選單圖示為 **「速」**
- [ ] Finder 中 `/Library/Input Methods/AppleSuCheng.app` 顯示名正確
- [ ] 只有繁中速成方案

## 輸入行為

- [ ] 打 `b` 預編輯顯示 **月**
- [ ] 單碼空白上屏；兩碼才出選字表
- [ ] Shift+數字選關聯；空白翻頁
- [ ] 候選超過一頁時首選旁有「→展開」；→ 展開成表格（直向 9 字一欄、橫向為各頁），← 在最左欄收起
- [ ] 展開後：方向鍵走格；1–9／Shift+1–9 選「焦點欄」；Enter 上屏焦點；滑鼠移到字上有單格高亮
- [ ] 輕按 Shift 切中英；按住 Shift 打字為小寫英文

## 技術

- [ ] Bundle ID 為 `com.applesucheng.inputmethod.SuCheng`
- [ ] Controller 為 `AppleSuCheng.AppleSuChengInputController`
- [ ] SharedSupport 有 `applesucheng.yaml`、opencc、lua
- [ ] 倉庫內無歷史上游前端專案英文名／其中文俗稱字樣（見 CI／本地 `git grep`）
