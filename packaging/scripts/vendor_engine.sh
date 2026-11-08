#!/bin/bash
# 把本機基底引擎 App 快取到 vendor/engine，讓之後 build 不依賴「剛好已安裝」
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DEST="$ROOT/vendor/engine/AppleSuCheng.app"

if [[ -n "${ASC_ENGINE_APP:-}" && -d "$ASC_ENGINE_APP" ]]; then
  SRC="$ASC_ENGINE_APP"
elif [[ -d "$ROOT/dist.noindex/AppleSuCheng.app" ]]; then
  SRC="$ROOT/dist.noindex/AppleSuCheng.app"
elif [[ -d "/Library/Input Methods/AppleSuCheng.app" ]]; then
  SRC="/Library/Input Methods/AppleSuCheng.app"
elif [[ -d "/Library/Input Methods/AppleSuCheng.app" ]]; then
  SRC="/Library/Input Methods/AppleSuCheng.app"
else
  echo "找不到可快取的引擎 App。請先安裝蘋果速成或蘋果速成預覽，或設 ASC_ENGINE_APP。" >&2
  exit 1
fi

echo "==> 快取引擎：$SRC → $DEST"
rm -rf "$ROOT/vendor/engine"
mkdir -p "$ROOT/vendor/engine"
cp -R "$SRC" "$DEST"
# 若來源仍是 AppleSuCheng 執行檔名，統一成 AppleSuCheng 方便後續腳本
if [[ -f "$DEST/Contents/MacOS/AppleSuCheng" && ! -f "$DEST/Contents/MacOS/AppleSuCheng" ]]; then
  mv "$DEST/Contents/MacOS/AppleSuCheng" "$DEST/Contents/MacOS/AppleSuCheng"
fi
echo "完成。之後 build_preview_app.sh 會優先用 vendor/engine。"
echo "注意：vendor/engine 為 GPL 二進位快取，已在 .gitignore，勿當自有原始碼提交。"
