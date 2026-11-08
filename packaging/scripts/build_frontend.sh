#!/bin/bash
# 編譯階段 B 前端 → build.noindex/frontend/AppleSuCheng.app（再跑 build_preview_app 灌入方案／圖示）
# 輸出資料夾以 .noindex 結尾：Spotlight 不掃，登入時才不會把開發副本登記成重複的輸入法
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FE="$ROOT/frontend"
OUT="$ROOT/build.noindex/frontend"

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "需要完整 Xcode 才能編譯 frontend。" >&2
  echo "請安裝 Xcode 後：sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
  exit 2
fi
[[ -f "$FE/PHASE_B_BRANDING.md" ]] || bash "$ROOT/packaging/scripts/apply_phase_b_branding.sh"
[[ -d "$FE/librime" ]] || { echo "請先：bash packaging/scripts/bootstrap_frontend.sh" >&2; exit 1; }

cd "$FE"
export MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-13.0}"
# 預設原生架構；要 Universal 可：ARCHS='arm64 x86_64' BUILD_UNIVERSAL=1
make release DERIVED_DATA_PATH=build.noindex ${ARCHS:+ARCHS="$ARCHS"} ${BUILD_UNIVERSAL:+BUILD_UNIVERSAL="$BUILD_UNIVERSAL"}

# 尋找產物
APP=$(find "$FE" -path '*/Build/Products/Release/*.app' -maxdepth 8 2>/dev/null | head -1 || true)
[[ -n "$APP" ]] || APP=$(find "$FE" -name 'AppleSuCheng.app' -o -name 'AppleSuCheng.app' 2>/dev/null | head -1 || true)
[[ -d "$APP" ]] || { echo "找不到編譯出的 .app" >&2; exit 1; }

rm -rf "$OUT"
mkdir -p "$OUT"
cp -R "$APP" "$OUT/AppleSuCheng.app"
# 統一執行檔名
if [[ -f "$OUT/AppleSuCheng.app/Contents/MacOS/AppleSuCheng" && ! -f "$OUT/AppleSuCheng.app/Contents/MacOS/AppleSuCheng" ]]; then
  mv "$OUT/AppleSuCheng.app/Contents/MacOS/AppleSuCheng" "$OUT/AppleSuCheng.app/Contents/MacOS/AppleSuCheng"
fi
# Xcode 會把產物登記進 LaunchServices；與安裝版同 ID 會讓 Fn 切換器跳過蘋果速成
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$APP" 2>/dev/null || true
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$OUT/AppleSuCheng.app" 2>/dev/null || true
echo "前端編譯完成：$OUT/AppleSuCheng.app"
echo "下一步：ASC_PHASE_B=1 ASC_ENGINE_APP=\"$OUT/AppleSuCheng.app\" bash packaging/scripts/build_preview_app.sh"
