#!/bin/bash
# 預覽包：自產「速」圖示 + Info.plist + 繁中速成 + Lua
# 階段 B：設 ASC_PHASE_B=1，或基底為 dist.noindex/frontend-build（自編譯前端）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DIST="$ROOT/dist.noindex"
APP="$DIST/AppleSuCheng.app"
ASSETS="$ROOT/website/assets"

bash "$ROOT/packaging/scripts/prepare_icons.sh"

# 基底引擎：環境變數 → 自編譯前端 → vendor → 已安裝 → 蘋果速成
if [[ -n "${ASC_ENGINE_APP:-}" && -d "$ASC_ENGINE_APP" ]]; then
  SRC="$ASC_ENGINE_APP"
elif [[ -d "$ROOT/build.noindex/frontend/AppleSuCheng.app" ]]; then
  SRC="$ROOT/build.noindex/frontend/AppleSuCheng.app"
elif [[ -d "$ROOT/vendor/engine/AppleSuCheng.app" ]]; then
  SRC="$ROOT/vendor/engine/AppleSuCheng.app"
elif [[ -d "/Library/Input Methods/AppleSuCheng.app" ]]; then
  SRC="/Library/Input Methods/AppleSuCheng.app"
elif [[ -d "/Library/Input Methods/AppleSuCheng.app" ]]; then
  SRC="/Library/Input Methods/AppleSuCheng.app"
else
  echo "找不到基底引擎 App。" >&2
  echo "階段 B：bash packaging/scripts/bootstrap_frontend.sh && bash packaging/scripts/build_frontend.sh" >&2
  echo "階段 A：bash packaging/scripts/vendor_engine.sh 或安裝蘋果速成" >&2
  exit 1
fi

# 自動階段判斷
PHASE_B="${ASC_PHASE_B:-0}"
case "$SRC" in
  *"/build.noindex/frontend/"*|*"/build/frontend/"*|*"/frontend-build/"*) PHASE_B=1 ;;
esac
if [[ -f "$SRC/Contents/SharedSupport/applesucheng.yaml" ]]; then PHASE_B=1; fi
# 自編譯二進位模組名為 AppleSuCheng 時必為階段 B
if strings "$SRC/Contents/MacOS/AppleSuCheng" 2>/dev/null | grep -q 'AppleSuCheng.AppleSuChengInputController'; then
  PHASE_B=1
fi
export ASC_PHASE_B="$PHASE_B"
if [[ "$PHASE_B" == "1" ]]; then PHASE_LABEL=B; else PHASE_LABEL=A; fi
echo "==> 基底引擎: $SRC"
echo "==> 階段 $PHASE_LABEL"
for f in sucheng.tiff AppIcon.icns logo.pdf logo.png; do
  [[ -f "$ASSETS/$f" ]] || { echo "缺少 $ASSETS/$f" >&2; exit 1; }
done
# 確保 Rime.tiff 存在（Fn 選單）
cp "$ASSETS/sucheng.tiff" "$ASSETS/Rime.tiff"

echo "==> 清理 dist"
rm -rf "$DIST"
mkdir -p "$DIST"

# Preferences 必須在清理 dist 之後建，否則會被刪掉
bash "$ROOT/packaging/scripts/build_preferences.sh"

echo "==> 複製基底並改名執行檔"
cp -R "$SRC" "$APP"
codesign --remove-signature "$APP" 2>/dev/null || true
find "$APP" -name '_CodeSignature' -type d -exec rm -rf {} + 2>/dev/null || true
if [[ -f "$APP/Contents/MacOS/AppleSuCheng" ]]; then
  mv "$APP/Contents/MacOS/AppleSuCheng" "$APP/Contents/MacOS/AppleSuCheng"
fi
# 若已是 AppleSuCheng 執行檔則保留
[[ -f "$APP/Contents/MacOS/AppleSuCheng" ]] || { echo "找不到執行檔" >&2; exit 1; }

INFO="$APP/Contents/Info.plist"
RES="$APP/Contents/Resources"
SUP="$APP/Contents/SharedSupport"

echo "==> 寫入 Info.plist（原機速成樣式圖示鍵）"
export ASC_INFO_PLIST="$INFO"
python3 <<'PY'
import os, plistlib
from pathlib import Path
info_path = Path(os.environ["ASC_INFO_PLIST"])
phase_b = os.environ.get("ASC_PHASE_B", "0") == "1"
with info_path.open("rb") as f:
    info = plistlib.load(f)

bundle = "com.applesucheng.inputmethod.SuCheng"
mode = f"{bundle}.Hant"
conn = "AppleSuCheng_Connection"

info["CFBundleIdentifier"] = bundle
info["TISInputSourceID"] = bundle
info["CFBundleName"] = "AppleSuCheng"
info["CFBundleDisplayName"] = "蘋果速成"
info["CFBundleExecutable"] = "AppleSuCheng"
info["CFBundleVersion"] = "0.2.0" if phase_b else "0.1.0"
info["CFBundleShortVersionString"] = info["CFBundleVersion"]
info["CFBundleIconFile"] = "AppIcon"
info["CFBundleIconName"] = "AppIcon"
info["TISIconIsTemplate"] = True
info["tsInputMethodIconFileKey"] = "sucheng.tiff"
info["TISIntendedLanguage"] = "zh-Hant"
info["TISParticipatesInTouchBar"] = True
info["tsInputMethodCharacterRepertoireKey"] = ["Hant"]
info["InputMethodConnectionName"] = conn
if phase_b:
    # 自編譯前端：PRODUCT_NAME 帶動模組名 AppleSuCheng
    ctrl = "AppleSuCheng.AppleSuChengInputController"
info["InputMethodServerControllerClass"] = ctrl
info["InputMethodServerDelegateClass"] = ctrl
info.pop("SUFeedURL", None)
info["SUEnableAutomaticChecks"] = False

hant = {
    "TISInputSourceID": mode,
    "TISIntendedLanguage": "zh-Hant",
    "TISIconLabels": {"Primary": "速"},
    "tsInputModeIsVisibleKey": True,
    # 與系統速成（Jianyi）相同；true 會讓選單／HUD 走偏
    "tsInputModePrimaryInScriptKey": False,
    "tsInputModeScriptKey": "smTradChinese",
    "tsInputModeKeyEquivalentKey": "S",
    "tsInputModeKeyEquivalentModifiersKey": 4608,
    "tsInputModeMenuIconFileKey": "sucheng.tiff",
    "tsInputModePaletteIconFileKey": "sucheng.tiff",
    "tsInputModeCharacterRepertoireKey": ["Hant"],
    "TISDoubleSpaceSubstitution": "。",
}
info["ComponentInputModeDict"] = {
    "tsInputModeListKey": {mode: hant},
    "tsVisibleInputModeOrderedArrayKey": [mode],
}
with info_path.open("wb") as f:
    plistlib.dump(info, f)
print(f"Info.plist OK ({bundle})")
PY

echo "==> 安裝選單／HUD 圖示（灰階 template，對齊系統速成）並移除舊 Assets.car"
# 選單列／Fn 膠囊用 template；彩圖只給 AppIcon
MENU_TIFF="$ASSETS/sucheng.tiff"
[[ -f "$MENU_TIFF" ]] || MENU_TIFF="$ASSETS/sucheng_own_template.tiff"
cp "$ASSETS/AppIcon.icns" "$RES/AppIcon.icns"
cp "$ASSETS/logo.pdf" "$RES/logo.pdf"
cp "$ASSETS/logo.png" "$RES/logo.png"
cp "$MENU_TIFF" "$RES/sucheng.tiff"
cp "$MENU_TIFF" "$RES/Rime.tiff"  # 相容舊 NSImage(named:"Rime")；圖素已是「速」
cp "$MENU_TIFF" "$RES/AppIcon.tiff"
[[ -f "$ASSETS/menu_su_32.png" ]] && cp "$ASSETS/menu_su_32.png" "$RES/Rime.png"
rm -f "$RES/Assets.car" "$RES/Rime.icns" "$RES/rime.pdf"
[[ -f "$ASSETS/keyboard_preview.png" ]] && cp "$ASSETS/keyboard_preview.png" "$RES/keyboard_preview.png"
# 不要把 .keylayout 放進輸入法 bundle：會註冊成衝突的 keylayout 輸入源並弄壞切換/打字
rm -f "$RES/AppleSuCheng.keylayout"
rm -rf "$RES/Preferences.prefPane"
cp -R "$ROOT/dist.noindex/Preferences.prefPane" "$RES/Preferences.prefPane"
[[ -f "$ASSETS/keyboard_preview.png" ]] && cp "$ASSETS/keyboard_preview.png" "$RES/Preferences.prefPane/Contents/Resources/keyboard_preview.png"

for lang in Base zh-Hant zh-Hans en; do mkdir -p "$RES/$lang.lproj"; done
# 系統設定第二行顯示父輸入法名稱；設成空字串才不會疊出兩行同名
cat > "$RES/Base.lproj/InfoPlist.strings" <<'EOF'
CFBundleDisplayName = "Apple SuCheng";
CFBundleName = "";
"com.applesucheng.inputmethod.SuCheng" = "";
"com.applesucheng.inputmethod.SuCheng.Hant" = "Apple SuCheng";
EOF
cat > "$RES/Base.lproj/Localizable.strings" <<'EOF'
"Apple SuCheng" = "Apple SuCheng";
"deploy_start" = "Deploying Apple SuCheng…";
"deploy_success" = "Apple SuCheng is ready.";
"deploy_failure" = "Deploy failed. Please check logs.";
"deploy_update" = "Updating Apple SuCheng…";
"Help..." = "Help...";
EOF
cat > "$RES/zh-Hant.lproj/InfoPlist.strings" <<'EOF'
CFBundleDisplayName = "蘋果速成";
CFBundleName = "";
NSHumanReadableCopyright = "Kanaoda · Apple SuCheng";
"com.applesucheng.inputmethod.SuCheng" = "";
"com.applesucheng.inputmethod.SuCheng.Hant" = "蘋果速成";
EOF
cat > "$RES/zh-Hant.lproj/Localizable.strings" <<'EOF'
"Apple SuCheng" = "蘋果速成";
"Deploy" = "重新部署";
"Settings..." = "用戶設定";
"Sync user data" = "同步用戶資料";
"Check for updates..." = "檢查更新…";
"Logs..." = "日誌…";
"Help..." = "使用說明…";
"deploy_start" = "正在部署蘋果速成…";
"deploy_success" = "蘋果速成已就緒。";
"deploy_failure" = "部署失敗，請查看日誌。";
"deploy_update" = "正在更新蘋果速成…";
EOF
cp "$RES/zh-Hant.lproj/InfoPlist.strings" "$RES/zh-Hans.lproj/"
cp "$RES/zh-Hant.lproj/Localizable.strings" "$RES/zh-Hans.lproj/"
cat > "$RES/en.lproj/InfoPlist.strings" <<'EOF'
CFBundleDisplayName = "Apple SuCheng";
CFBundleName = "";
"com.applesucheng.inputmethod.SuCheng" = "";
"com.applesucheng.inputmethod.SuCheng.Hant" = "Apple SuCheng";
EOF
cat > "$RES/en.lproj/Localizable.strings" <<'EOF'
"Apple SuCheng" = "Apple SuCheng";
"deploy_start" = "Deploying Apple SuCheng…";
"deploy_success" = "Apple SuCheng is ready.";
"deploy_failure" = "Deploy failed. Please check logs.";
"deploy_update" = "Updating Apple SuCheng…";
"Help..." = "Help...";
EOF

echo "==> SharedSupport（只留蘋果速成 + Lua）"
if [[ ! -f "$ROOT/input-method/schema/apple_sucheng.schema.yaml" ]]; then
  echo "缺少 input-method/schema/apple_sucheng.schema.yaml" >&2
  exit 1
fi
if [[ ! -f "$ROOT/input-method/lua/sucheng_keys.lua" || ! -f "$ROOT/input-method/lua/sucheng_hint.lua" ]]; then
  echo "缺少 input-method/lua/sucheng_*.lua" >&2
  exit 1
fi
# 清方案前先保住 OpenCC（缺了 IM 會起不來，系統就把它從選單拿掉）
OPENCC_TMP="$(mktemp -d)"
if [[ -d "$SUP/opencc" ]]; then
  cp -R "$SUP/opencc" "$OPENCC_TMP/opencc"
elif [[ -d "$SRC/Contents/SharedSupport/opencc" ]]; then
  cp -R "$SRC/Contents/SharedSupport/opencc" "$OPENCC_TMP/opencc"
fi
rm -rf "$SUP"
mkdir -p "$SUP/lua"
if [[ -d "$OPENCC_TMP/opencc" ]]; then
  cp -R "$OPENCC_TMP/opencc" "$SUP/opencc"
fi
rm -rf "$OPENCC_TMP"
for extra in symbols.yaml essay.txt; do
  [[ -f "$SRC/Contents/SharedSupport/$extra" ]] && cp "$SRC/Contents/SharedSupport/$extra" "$SUP/" || true
done
cp "$ROOT/input-method/schema/default.yaml" "$SUP/"
cp "$ROOT/input-method/theme/ui.yaml" "$SUP/applesucheng.yaml"
cp "$ROOT/input-method/schema/punctuation.yaml" "$SUP/"
cp "$ROOT/input-method/schema/key_bindings.yaml" "$SUP/"
cp "$ROOT/input-method/schema/apple_sucheng.schema.yaml" "$SUP/"
cp "$ROOT/input-method/dict/apple_sucheng.dict.yaml" "$SUP/"
cp "$ROOT/input-method/dict/predict.db" "$SUP/"
cp "$ROOT/input-method/lua/sucheng_keys.lua" "$SUP/lua/"
cp "$ROOT/input-method/lua/sucheng_hint.lua" "$SUP/lua/"
[[ -d "$SUP/opencc" ]] || { echo "錯誤：SharedSupport 缺少 opencc/" >&2; exit 1; }

echo "==> 替換上游 README／說明（避免包內仍寫上游舊名）"
cat > "$RES/README.md" <<'EOF'
# 蘋果速成 / Apple SuCheng

Author: Kanaoda

macOS 繁體中文速成輸入法（預覽包）。

- 方案與 Lua 行為：產品自有（MIT）
- 本預覽 `.app` 的輸入法前端實作依賴開源引擎（階段 A）；詳見應用程式內 NOTICE／LICENSE

專案：https://github.com/Kanaoda
支持：https://buymeacoffee.com/kanaoda · https://github.com/sponsors/Kanaoda
EOF
# 若基底帶了上游蘋果速成 README／說明，以產品 NOTICE 覆蓋說明義務
[[ -f "$ROOT/NOTICE" ]] && cp "$ROOT/NOTICE" "$RES/NOTICE.txt"
# 保留引擎 LICENSE.txt（GPL 義務）；若無則略過
if [[ -f "$RES/LICENSE.txt" ]]; then
  {
    echo "=== Apple SuCheng preview bundle ==="
    echo "Engine front-end license (upstream) follows below."
    echo
    cat "$RES/LICENSE.txt"
  } > "$RES/LICENSE.txt.tmp"
  mv "$RES/LICENSE.txt.tmp" "$RES/LICENSE.txt"
fi

codesign --force --deep --sign - "$APP"
echo "==> 完成：$APP"
echo "圖示檢查："
file "$RES/sucheng.tiff" "$RES/AppIcon.icns"
python3 - <<PY
import plistlib, os
from pathlib import Path
info=plistlib.loads(Path("$INFO").read_bytes())
phase_b = os.environ.get("ASC_PHASE_B", "0") == "1"
mode_id = "com.applesucheng.inputmethod.SuCheng.Hant"
assert info.get("TISIconIsTemplate") is True
mode=info["ComponentInputModeDict"]["tsInputModeListKey"][mode_id]
assert mode["tsInputModeMenuIconFileKey"]=="sucheng.tiff"
assert mode["tsInputModeScriptKey"]=="smTradChinese"
assert Path("$RES/Preferences.prefPane").exists()
assert Path("$SUP/lua/sucheng_keys.lua").is_file()
assert Path("$SUP/lua/sucheng_hint.lua").is_file()
assert Path("$SUP/apple_sucheng.schema.yaml").is_file()
assert info.get("CFBundleIdentifier") == "com.applesucheng.inputmethod.SuCheng"
assert Path("$SUP/applesucheng.yaml").is_file()
readme = Path("$RES/README.md").read_text(encoding="utf-8")
banned = bytes.fromhex("537175697272656c").decode()
assert banned not in readme and ("鼠" + "鬚管") not in readme and ("鼠" + "须管") not in readme
assert os.path.getsize(f"$RES/sucheng.tiff") > 1000
print("驗收 OK：SharedSupport+lua、產品 README、Preferences.prefPane" + ("、階段 B ID" if phase_b else ""))
PY
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$APP" 2>/dev/null || true
echo "下一步：bash packaging/scripts/install_preview.sh"
