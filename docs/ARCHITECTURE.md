# 架構說明（為什麼不是照抄引擎目錄）

蘋果速成把「產品行為」和「發行包裝」拆開：

## `input-method/`＝產品本體

- `schema/`：方案與預設（`apple_sucheng`）
- `dict/`：碼表與聯想庫
- `lua/`：
  - `sucheng_keys.lua`：按鍵節奏（單碼、Shift 選關聯字、空白翻頁、Shift 小寫英文）
  - `sucheng_hint.lua`：關聯字提示、九格占位、中文預編輯維持
- `theme/`：選字表外觀（Windows 速成風格）

這裡的檔名與模組名都是 **Apple SuCheng / Sucheng** 語意，不沿用第三方前端的目錄習慣。

## `packaging/`＝怎麼變成 macOS 輸入法 App

預覽階段用腳本把產品資源打進可安裝的 `.app`。  
建置基底優先順序：`ASC_ENGINE_APP` → `vendor/engine/` → 已安裝 App。  
正式版會改為獨立前端工程，但 **輸入行為仍以 `input-method/` 為唯一來源**，避免「結果靠改別人樹狀目錄」的結構。

`dist.noindex/` 為建置產物（gitignore），以 `input-method/` + 腳本為準，勿手改 dist。

## `website/`＝給人看、給搜尋／AI 看的入口

短介紹、作者、贊助連結（Buy Me a Coffee / GitHub Sponsors）。
