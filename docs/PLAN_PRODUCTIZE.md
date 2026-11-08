# 計畫：抹去 AppleSuCheng 指紋 → 獨立產品「蘋果速成」

目標（產品意圖，不是 hybrid 終態）：在 GitHub／發行物上以 **Apple SuCheng / 蘋果速成** 出現；系統身分、目錄、原始碼命名、文件皆不依賴蘋果速成指紋。使用者裝的是你的輸入法，不是改皮 AppleSuCheng。

**回滾點**：桌面備份  
`~/Desktop/AppleSuCheng-backup-20261108-0330-hybrid-working/`  
（hybrid v0.2.0，已驗證可打字；見內附 `RESTORE.md`）

---

## 現況一句話

外觀與資料目錄已是蘋果速成；**Bundle ID 仍是 `com.applesucheng.inputmethod.SuCheng`**（新 ID TIS 註冊失敗後退回）。倉庫內仍有大量 `AppleSuCheng*` 類名／工程名／上游包裝殘渣。打包腳本在 `ASC_PHASE_B=1` 時仍假設「新 Bundle ID 已成功」。

---

## 原則

1. **先解系統身分，再改原始碼命名** — 只 rename 類名無法讓 GitHub 使用者拿到獨立輸入法。
2. **每階段可回滾** — 改動前後保留可安裝的 `.app`；重大節點再做一次 Desktop 備份。
3. **不要散佈系統 `sucheng.tiff`** — 發行只用自產圖示。
4. **開發產物一律 `*.noindex`** — 避免 Spotlight 重複登記。
5. **GPL fork 義務保留** — 抹指紋 ≠ 刪 NOTICE／上游授權；產品碼可 MIT，前端仍 GPL 並標明 fork。

---

## 階段 0 — 安全網（✅ 已做）

- [x] 備份目前可用 hybrid 到 Desktop
- [x] 文件寫明 hybrid ≠ 終態（`PHASE_B.md` / `BRANDING.md` / `HANDOFF.md`）
- [x] xcstrings 改產品字串（減少 Xcode 直編露蘋果速成）

---

## 階段 1 — 解 TIS：真正的產品 Bundle ID（阻塞項）

**為何最優先：** 沒有穩定的 `com.applesucheng.inputmethod`（或你選定的新 ID），GitHub 發行永遠只能「掛羊頭」用蘋果速成 ID，也無法與本機真蘋果速成共存。

### 1.1 釐清上次失敗原因（先蒐證，再改碼）

建議對照實驗（每次只改一個變數）：

| 假設 | 檢查 |
|------|------|
| 舊 ID 殘留佔住 | `lsregister -dump`／系統設定輸入法清單是否仍有 AppleSuCheng／舊 AppleSuCheng |
| 新 ID 未進信任路徑 | 是否只放在 `dist.noindex`、未 `lsregister -f -R -trusted` 到 `/Library/Input Methods` |
| Info.plist 模式鍵不一致 | `TISInputSourceID`、`ComponentInputModeDict`、`InputSource.swift` 的 mode raw value 是否同一字串 |
| Connection／Controller 不匹配 | 新 ID + 舊 connection 名；或模組名與 `InputMethodServerControllerClass` 不符 |
| 簽名／閘道 | ad-hoc 是否導致啟用後被系統卸掉（看 Console：`TextInputMenuAgent`／`HIToolbox`） |
| 與 hybrid 並行衝突 | 同機同時存在兩套 Contoller／同 Connection 名 |

產出：`docs/TIS_NEW_ID_NOTES.md`（失敗現象 + 重現步驟 + 成功條件）。

### 1.2 成功定義（驗收）

- [ ] `/Library/Input Methods/AppleSuCheng.app` 的 `CFBundleIdentifier` = `com.applesucheng.inputmethod`（或定案 ID）
- [ ] 模式 ID = `{bundle}.Hant` 僅繁中
- [ ] 系統設定可 **＋加入**、Fn 可選到、可連續打字（單碼／關聯／Shift 中英）
- [ ] 本機**沒有**再依賴 `com.applesucheng.inputmethod.SuCheng` 才能出現在清單
- [ ] 重開機／登出後仍在

### 1.3 對齊腳本（成功後立刻做）

- 改 `apply_phase_b_branding.sh`、`build_preview_app.sh`、`install_preview.sh`：只產／只 assert **新 ID**
- 刪除或隔離「階段 A 改皮必須用蘋果速成 ID」的預設路徑（或明確標成 deprecated）
- 更新 `docs/PHASE_B.md`：hybrid 標成歷史，現況 = 完整產品 ID

**若短期解不了 TIS：** 可並行做階段 2 的「倉庫內去指紋」，但 **不可對 GitHub 宣稱已獨立於 AppleSuCheng 身分**；README 須誠實寫系統 ID 現況。

---

## 階段 2 — 打包與倉庫：對外不再長得像蘋果速成

在階段 1 成功（或明確標記「ID 仍 hybrid」）後：

### 2.1 產品表面

- [ ] 根 `README.md`、website、包內 README／NOTICE：產品敘事為主；上游僅授權段落提及
- [ ] 移除／改寫 `frontend/README.md`、`INSTALL.md`、`SKILL.md`、`.github` issue 模板中的蘋果速成使用說明
- [ ] `frontend/package/*`、`postinstall`：改成蘋果速成安裝敘事或移出發行路徑
- [ ] 死碼：`packaging/keyboard/*.keylayout`、重複 website 資產

### 2.2 建置路徑單一化

- [ ] `bootstrap_frontend` → `build_frontend` → `build_preview_app` → `install_preview` 一條龍，輸出永遠產品名
- [ ] 禁止預設 fallback 到 `/Library/Input Methods/AppleSuCheng.app`（或僅 debug 旗標）
- [ ] 清掉 `AppleSuChengIM.app` 等舊名殘留說明

### 2.3 本機資料

- [ ] 文件化：全新使用者只有 `~/Library/AppleSuCheng` + 產品方案
- [ ] 可選：清理腳本去掉 `ms_quick.*`、`AppleSuCheng.custom.yaml`、`luna_pinyin.userdb`（開發機雜物）

---

## 階段 3 — 原始碼去指紋（可讀性／品牌，非功能必須）

大改前再做一次 Desktop 備份。

建議順序（減少一次爆改）：

1. **字串與設定鍵**（已部分完成）：xcstrings、yaml 檔名、通知名 `AppleSuCheng*Notification`
2. **工程／產物名**：`AppleSuCheng.xcodeproj` → `AppleSuCheng.xcodeproj`；`PRODUCT_NAME`／scheme
3. **Swift 檔與型別名**：`AppleSuChengInputController` → `AppleSuChengInputController` 等（與 Info.plist Controller 字串同步）
4. **殘餘 API／註解／log** 中的 AppleSuCheng／Rime 使用者可見字樣（引擎名「Rime」若屬協議可留在開發者 log，但 UI 不要出現）

每步：編譯 → `build_preview_app` → 安裝 →跑 `docs/ACCEPTANCE.md`。

---

## 階段 4 — GitHub 產品化發行

- [ ] 建 remote、授權（MIT 產品 + GPL 前端 NOTICE）清楚
- [ ] 正式簽名／公證（或文件寫明 ad-hoc + Gatekeeper 步驟）
- [ ] Release 產物：`.app`／`.pkg`／安裝說明；**不要**要求使用者先裝蘋果速成
- [ ] 驗收清單對外版（使用者向）與對內版（TIS／Bundle ID）分離
- [ ]（可選）Sparkle 自有 feed

---

## 建議執行順序（精簡）

```
Desktop 備份 ✅
    → 階段 1：蒐證並打通新 Bundle ID（最大風險）
        → 腳本／文件對齊新 ID
            → 階段 2：清上游文件與 package 指紋
                → 階段 3：類名／xcodeproj rename
                    → 階段 4：簽名 + GitHub Release
```

---

## 明確不做／暫緩

| 項 | 原因 |
|----|------|
| 未解 TIS 就全面改 Bundle ID 並推給使用者 | 會裝了卻選不到／不能打字 |
| 把 GPL 前端改成宣稱 MIT | 授權違規 |
| 散佈 Apple TCIM `sucheng.tiff` | 版權／發行風險 |
| 用 LaunchAgent 每 N 秒重寫輸入法清單 | 已否決，傷系統設定 |
| `Primary` 改成「速成」 | Fn／選單顯示錯誤（必須單字「速」） |

---

## 下一步（建議立刻做的一件事）

開新任務：**階段 1.1 蒐證** — 重現「新 Bundle ID 註冊失敗」的最小步驟，寫進 `docs/TIS_NEW_ID_NOTES.md`，再決定是修 plist／register 流程，還是改 ID 策略。

在那之前，本機繼續用 Desktop 備份的 hybrid；不要重跑會強改 Bundle ID 的 branding，除非已在實驗分支且可回滾。
