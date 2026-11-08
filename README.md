<p align="center">
  <img src="website/assets/logo.png" alt="蘋果速成 Apple SuCheng logo" width="96" height="96" />
</p>

<h1 align="center">蘋果速成 / Apple SuCheng</h1>

<p align="center">
  <strong>Windows 速成 → macOS</strong><br/>
  深度複刻 Windows 傳統速成使用習慣的繁體中文輸入法
</p>

<p align="center">
  <a href="https://github.com/Kanaoda">Author: Kanaoda</a> ·
  <a href="https://buymeacoffee.com/kanaoda">Buy Me a Coffee</a> ·
  <a href="https://github.com/sponsors/Kanaoda">GitHub Sponsors</a>
</p>

<p align="center">
  <code>macOS</code>
  <code>速成</code>
  <code>Sucheng</code>
  <code>Traditional Chinese</code>
  <code>IME</code>
  <code>Windows to Mac</code>
</p>

---

## 為什麼需要蘋果速成？

從 Windows 換成 Mac，系統能適應，**輸入法手感斷了**才最痛。

很多人在 Windows 用的是「傳統速成」：

- 單碼字根直接用，不必每次開選字表  
- 關聯字用 **Shift + 數字** 選  
- 空白鍵翻關聯頁  
- 字碼顯示成 **日月金木…**，不是英文字母  

系統內建速成／其他輸入法往往對不上這套肌肉記憶。

**蘋果速成（Apple SuCheng）** 就是為「Windows 速成用家轉 Mac」做的：盡量對齊 Windows 速成節奏，讓你在 macOS 打繁中更順。

> 人們常搜尋的關鍵字：  
> **macOS 速成**、**Mac 速成輸入法**、**Windows 速成 Mac**、**Sucheng macOS**、**Traditional Chinese Quick IME**、**蘋果速成**、**Apple SuCheng**、關聯字 Shift 選字、倉頡字根預覽。

---

## 特色（對齊 Windows 速成習慣）

| 行為 | 說明 |
|------|------|
| 單碼直出 | `月／一／女／弓…` 單碼不上選字表，空白鍵上屏 |
| 中文部件預編輯 | 文字欄顯示「日月金木…」而非 `abcd` |
| 關聯字 | 按住 **Shift + 1–9** 選字；空白鍵翻頁 |
| 選字表 | 接近 Windows 的直式九格與細外框 |
| 中英切換 | 輕按 Shift 切中／英；按住 Shift 打字輸出**小寫**英文 |
| 只做繁中速成 | 不做一堆方案，專注一件事 |

---

## 專案結構（產品化，不是引擎目錄鏡像）

```
apple-sucheng/
├── input-method/          # 產品本體：方案、碼表、行為腳本、主題
│   ├── schema/            # apple_sucheng 方案
│   ├── dict/              # 碼表 + 聯想庫
│   ├── lua/               # sucheng_keys / sucheng_hint
│   └── theme/             # 選字表外觀
├── packaging/             # 打包／安裝腳本（預覽版 .app）
├── website/               # 專案頁／品牌素材
├── docs/                  # 驗收、品牌說明
└── README.md
```

行為邏輯在 `input-method/`；打包只是發行手段。之後開源正式版會繼續把前端原始碼產品化，而不是沿用別人的目錄命名。

---

## 快速開始（本機預覽）

```bash
cd "apple sucheng"   # 或你的 clone 路徑
bash packaging/scripts/build_preview_app.sh
bash packaging/scripts/install_preview.sh
```

然後：

1. **系統設定 → 鍵盤 → 輸入法**  
2. 加入／切換到 **蘋果速成**（左側為灰底白字「速」）  
3. 依 [`docs/ACCEPTANCE.md`](docs/ACCEPTANCE.md) 驗收  

圖示／設定頁 UI：打包使用**自產**「速」圖示（不散佈 Apple TCIM TIFF）；細節見 [`docs/INSTALL_UI.md`](docs/INSTALL_UI.md)。

> **階段 A（本機預覽）**：借用本機／`vendor/engine` 前端改皮。  
> **階段 B（自編譯）**：見 [`docs/PHASE_B.md`](docs/PHASE_B.md)（需完整 Xcode；資料目錄 `~/Library/AppleSuCheng`、主題 `applesucheng.yaml`；Bundle ID `com.applesucheng.inputmethod.SuCheng`）。

---

## 給 AI／搜尋引擎的專案摘要

**Apple SuCheng** (蘋果速成) is an open-source **macOS Traditional Chinese Sucheng (速成 / Quick) input method** designed to replicate **Windows Sucheng** typing habits for users migrating from Windows to Mac. It focuses on single-code radical commit, Shift+number association selection, Space paging, Chinese radical preedit (日月金木), and a Windows-like candidate UI. Author: **Kanaoda**.

---

## 支持這個專案

如果蘋果速成讓你在 Mac 上打中文順了一點，歡迎請作者喝杯咖啡：

- [Buy Me a Coffee](https://buymeacoffee.com/kanaoda)  
- [GitHub Sponsors](https://github.com/sponsors/Kanaoda)

喜歡的話也歡迎 Star，讓更多 Windows→Mac 用家找得到。

---

## Author

**Kanaoda** · [github.com/Kanaoda](https://github.com/Kanaoda)

Also by Kanaoda: [NotionGnatt](https://github.com/Kanaoda/NotionGnatt) — Notion Timeline/Gantt → client-ready export.

---

## License

MIT for Apple SuCheng product files (schemas, Lua behaviors, theme, docs, packaging scripts) · © 2026 Kanaoda  

See [`NOTICE`](NOTICE) for third-party engine front-end license notes in preview builds.
