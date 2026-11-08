# TIS 新 Bundle ID 蒐證筆記

目標 ID：`com.applesucheng.inputmethod`／模式 `com.applesucheng.inputmethod.Hant`  
回滾：`~/Desktop/AppleSuCheng-backup-20261108-0330-hybrid-working/`

## 2026-11-08 基線（實驗前）

| 項 | 值 |
|----|-----|
| 安裝路徑 | `/Library/Input Methods/AppleSuCheng.app` |
| Bundle ID | `com.applesucheng.inputmethod.SuCheng` |
| 模式 | `com.applesucheng.inputmethod.SuCheng.Hant` |
| Controller | `AppleSuCheng.AppleSuChengInputController` |
| Connection | `AppleSuCheng_Connection` |
| 使用者目錄／主題 | `~/Library/AppleSuCheng`、`applesucheng.yaml` |
| 真蘋果速成 App | 不在 `/Library/Input Methods/`（已無 `AppleSuCheng.app`） |

`lsregister` 曾掃到桌面備份與 `frontend/build/...` 開發產物（同 ID）→ 已嘗試 `-u` 解除；開發產物必須 `*.noindex`。

## 最可能失敗根因（尚未實測前的假設）

### A. 二進位 mode 字串與 Info.plist 不一致（高）

目前**已安裝二進位** `strings` 可見：

- `com.applesucheng.inputmethod.SuCheng.Hant`
- `Failed to select com.applesucheng.inputmethod.SuCheng.Hant`

對應原始碼 `InputSource.swift`：

```swift
case hant = "com.applesucheng.inputmethod.SuCheng.Hant"
```

`build_preview_app.sh` 在 `ASC_PHASE_B=1` 時**只改 Info.plist** 成 `com.applesucheng.inputmethod*`，**不會重編**前端。結果：

1. 系統依 plist 登記 `com.applesucheng.inputmethod.Hant`
2. App 的 `--enable`／`--select` 仍找 `…AppleSuCheng.Hant` → 失敗
3. `AppleSuChengApplicationDelegate` 用 `hasPrefix("com.applesucheng.inputmethod.SuCheng")` 判斷狀態列 → 新 ID 下行為錯

`apply_phase_b_branding.sh` 會改 `InputSource.swift`／pbxproj，但重跑它與「現況 hybrid 源碼」不同步；HANDOFF 曾警告勿盲跑。

### B. 同路徑換 Bundle ID 的 TIS／LS 快取（中）

同一 `/Library/Input Methods/AppleSuCheng.app` 從舊 ID 換成新 ID，Launch Services／輸入法清單可能殘留舊來源。需 `lsregister -f -R -trusted`、重啟 `TextInputMenuAgent`，必要時登出。

### C. 僅改皮、未重編就宣稱階段 B（中）

腳本把「自編譯前端」自動標成 `PHASE_B=1` 並寫新 ID，但源碼／二進位仍是 AppleSuCheng mode → 結構性自相矛盾。

## 實驗設計

1. **Experiment 1（plist-only）**：用現有可用二進位，只改 Info.plist → 新 ID；靠 `install_preview` 的 Swift TIS（依 plist Bundle ID + `.Hant`）啟用，不依賴 App `--select`。  
   - 成功：TIS 清單出現新 ID，可 Select → 證明系統接受新 ID，缺的是二進位對齊。  
   - 失敗：記錄 Console／TIS 清單，可能是 B 或其他。
2. **Experiment 2（源碼對齊 + 重編）**：改 `InputSource`、`hasPrefix`、`PRODUCT_BUNDLE_IDENTIFIER` 後重編再裝。
3. 任一失敗 → 立刻還原 Desktop hybrid 備份。

## 實驗紀錄

### Experiment 1 — plist-only（2026-11-08）

作法：用已驗證 hybrid 二進位，只改 Info.plist／InfoPlist.strings → `com.applesucheng.inputmethod`；不安裝依賴 App `--select`（仍硬編碼舊 mode）。

| 步驟 | 結果 |
|------|------|
| 安裝到 `/Library/Input Methods` + `lsregister -trusted` | OK |
| App `--install` | 印出 Registered… |
| TIS 清單 | **出現** `com.applesucheng.inputmethod` 與 `.Hant` |
| `TISEnableInputSource` | **0（成功）** |
| `TISSelectInputSource(.Hant)` | **-50（paramErr）** |
| 數秒後再查清單 | 新／舊 ID **皆消失**；目前鍵盤變 `com.apple.keylayout.US` |
| App `--select-input-source` | `Default method not enabled yet: com.applesucheng.inputmethod.SuCheng.Hant`（二進位硬編碼，預期失敗） |

結論：

1. **系統可以登記新 Bundle ID**（不是「新 ID 永遠進不了 TIS」）。
2. **卡住點在 Select／穩定可選**，不是 Register 本身。
3. 只改 plist、不重編 → CLI 選源必失敗；且可能讓來源不穩定（實驗後清單被清空）。
4. 已用 Desktop hybrid 備份還原；還原後 `.Hant` `selectCapable=true`，`TISSelect` → 0，`current=…AppleSuCheng.Hant`。

對照還原後健康狀態：

- 父 bundle `…AppleSuCheng`：`selectCapable=false`（正常，只當容器）
- 模式 `…AppleSuCheng.Hant`：`selectCapable=true`、可 Select

### Experiment 2 — 源碼對齊 + 重編（2026-11-08）

已改並重編成功（`build.noindex/frontend` + `dist.noindex`）：

1. `InputSource.swift` → `com.applesucheng.inputmethod.Hant`
2. `AppleSuChengApplicationDelegate` `hasPrefix` → `com.applesucheng.inputmethod`
3. `PRODUCT_BUNDLE_IDENTIFIER` → `com.applesucheng.inputmethod`
4. `resources/Info.plist` 模式鍵對齊；`PrimaryInScriptKey=false`
5. 二進位 `strings` 已見新 mode（不再硬編碼 AppleSuCheng.Hant）

**安裝結果：失敗／危險**

- `install_preview.sh` 跑完後，`/Library/Input Methods/AppleSuCheng.app` 變成**殘缺 bundle**（有 Frameworks／MacOS／Resources，但 **沒有 `Contents/Info.plist`**）
- 輸入法清單一度異常；已用 Desktop hybrid 備份強制覆寫還原
- 還原後：`TISSelect(…AppleSuCheng.Hant)` → 0，`current=…AppleSuCheng.Hant`（可用）

待查：`install_preview` 的 `rm -rf` + `cp -R` 為何產出無 Info.plist 的 App（權限／路徑空白／codesign？）。在查清前 **不要再對系統目錄安裝新 ID 包**。

倉庫狀態：源碼／dist 已是新 ID；**本機安裝版刻意維持 hybrid 備份**。下一輪安裝改用更穩流程（例如 `ditto`、安裝後 assert Info.plist 存在，失敗立刻 rollback）。

**在 Experiment 2 安裝驗證成功前，本機維持 hybrid。**

### Experiment 2b — hardened installer (same day)

- ditto/assert/rollback: on-disk Info.plist = `com.applesucheng.inputmethod` (complete app)
- `lsregister -dump` for same path still showed `com.applesucheng.inputmethod.SuCheng`
- TIS had no `com.applesucheng*`; app --select could not find new mode
- Root cause: Launch Services cache not updated when Bundle ID changes on same path
- Rolled back to Desktop hybrid again

### Experiment 3 — next

1. `-u` before install; confirm path gone from dump
2. ditto + `-f -R -trusted`
3. assert dump identifier == plist Bundle ID before Enable (script now checks this)
4. if LS stuck: bump CFBundleVersion, temp different path name, or logout/login

### Experiment 3 result (2026-11-08)

What worked:
- After careful install, `lsregister` can show `identifier: com.applesucheng.inputmethod` (same path or fresh path).
- Disk Info.plist / codesign Identifier can match the new Bundle ID.
- Bug found: backup `.metadata_never_index` inside `.app` root breaks codesign (`unsealed contents`); moved marker beside the app.
- Bug found: LS dump path matching via `index(path)` falsely hits Sparkle `Updater.app` under the IM; scripts must exact-match path.

What failed:
- Even with LS correct + `TISRegister` status 0 + working hybrid binary patched to new plist, **`TISCreateInputSourceList` shows zero `com.applesucheng*` sources**.
- Fresh path `AppleSuChengProduct.app` same result: LS OK, TIS empty for new ID.
- Replacing main app with new ID removes old AppleSuCheng from TIS and does **not** add new ID (`related_count 0`).
- Auto-rollback to Desktop hybrid restores typing (`current=…AppleSuCheng.Hant`).

Interpretation:
- Same-path LS cache was real, but **not sufficient**. On this macOS, a **new input-method Bundle ID does not become a TIS source** with the current ad-hoc install flow (may need logout/login, Developer ID notarization, or manual System Settings add).
- Keeping `com.applesucheng.inputmethod.SuCheng` remains the only reliably selectable identity today.

### Experiment 4 — candidate next steps (needs user)

1. Install new-ID app, **log out and log in**, then check whether `com.applesucheng.inputmethod.Hant` appears under System Settings → Keyboard → Input Sources (and in TIS list).
2. If still missing: try signing with Apple Development / Developer ID + notarize, reinstall.
3. Interim product strategy: ship hybrid ID honestly, or document Gatekeeper + logout steps once 4.1 works.

## 真正根因（GitHub / Apple SDK，非猜測）

我們之前用的 Bundle ID：

- ❌ `com.applesucheng.inputmethod` — **不含**子字串 `.inputmethod.`（少了後面那一段產品名）
- ✅ `com.applesucheng.inputmethod.SuCheng` — 含 `.inputmethod.`
- ✅ `com.applesucheng.inputmethod.SuCheng` — 含 `.inputmethod.`

證據：

1. Apple `TextInputSources.h`：mode ID 建構會找 ends with `.inputmethod.` 的前綴
2. Stack Overflow / IMKit sample：`Bundle Identifier must contain \`.inputmethod.\``
3. GitHub `AlienKevin/sample_imkit_*`、`ensan-hcl/macOS_IMKitSample_2021`：建立專案時明確要求
4. Apple DTS forum：新 Input Source 要出現在系統設定，現代 macOS **仍可能要登出再登入**（與 TIS 列舉是兩件事）

### 2026-11-08 驗證（改名後）

安裝 `com.applesucheng.inputmethod.SuCheng` 後：

- `TISCreateInputSourceList`：**FOUND** 父 bundle + `.Hant`（先前 related_count 曾是 0）
- `TISEnable`：`.Hant` 成功
- `TISSelect`：仍 **-50**；`current` 仍 US → 下一步依 Apple DTS：**登出／登入** 或系統設定手動加入
- 為保持可打字，本機暫還原 Desktop hybrid；**倉庫已改正確 Bundle ID**

