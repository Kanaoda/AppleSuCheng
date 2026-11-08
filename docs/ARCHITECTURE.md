# 架構說明

蘋果速成把「產品行為」和「發行包裝」拆開：

## `input-method/`＝產品本體

- `schema/`：方案與預設（`apple_sucheng`）
- `dict/`：碼表與聯想庫
- `lua/`：按鍵節奏、關聯提示、中文預編輯
- `theme/`：選字表外觀（Windows 速成風格）

## `frontend/`＝macOS 輸入法前端（GPL-3.0）

可編譯的 InputMethodKit 前端；產品 Bundle ID、主題、資料目錄見 `docs/PHASE_B.md`。

## `packaging/`＝打包／安裝／Release

- `build_frontend.sh` → 編譯前端  
- `build_preview_app.sh` → 灌入方案、圖示、偏好設定  
- `install_preview.sh` → 本機開發安裝  
- `make_release.sh` → 一般用戶 zip 安裝包  

產物在 `dist.noindex/`（gitignore）。

## `website/`＝專案頁與品牌素材
