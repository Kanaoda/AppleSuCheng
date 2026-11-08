#!/bin/bash
# 將 frontend/（AppleSuCheng fork）套上蘋果速成階段 B 品牌：Bundle ID、資料目錄、主題檔名、繁中-only
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FE="$ROOT/frontend"
[[ -d "$FE/sources" ]] || { echo "缺少 $FE（請先準備 frontend 分叉）" >&2; exit 1; }

# MUST contain ".inputmethod." (with trailing product segment). Plain
# "com.applesucheng.inputmethod" is NOT enumerated by TIS.
BUNDLE_ID="com.applesucheng.inputmethod.SuCheng"
MODE_HANT="${BUNDLE_ID}.Hant"
USER_DIR_NAME="AppleSuCheng"
APP_NAME="AppleSuCheng"
UI_YAML="applesucheng.yaml"
CONN="AppleSuCheng_Connection"

echo "==> 階段 B 品牌：$BUNDLE_ID / ~/$USER_DIR_NAME / $UI_YAML"

# --- 主題檔改名 ---
if [[ -f "$FE/data/applesucheng.yaml" && ! -f "$FE/data/$UI_YAML" ]]; then
  mv "$FE/data/applesucheng.yaml" "$FE/data/$UI_YAML"
fi
# 產品主題覆蓋（若有）
if [[ -f "$ROOT/input-method/theme/ui.yaml" ]]; then
  cp "$ROOT/input-method/theme/ui.yaml" "$FE/data/$UI_YAML"
fi

# --- Main.swift：使用者目錄／App 路徑／log ---
python3 - <<PY
from pathlib import Path
p = Path("$FE/sources/Main.swift")
t = p.read_text(encoding="utf-8")
t = t.replace('appending(components: "Library", "Rime")', 'appending(components: "Library", "$USER_DIR_NAME")')
t = t.replace('appendingPathComponent("Rime", isDirectory: true)', 'appendingPathComponent("$USER_DIR_NAME", isDirectory: true)')
# appDir 使用 Bundle.main.bundleURL（勿再寫死路徑）
if "static var appDir: URL { Bundle.main.bundleURL }" not in t:
    t = t.replace('"/Library/Input Methods/AppleSuCheng.app"', '"/Library/Input Methods/$APP_NAME.app"')
t = t.replace('temporaryDirectory.appending(component: "rime.applesucheng"', 'temporaryDirectory.appending(component: "rime.applesucheng"')
t = t.replace('"rime.applesucheng-builder"', '"rime.applesucheng-builder"')
# 通知名保留 AppleSuCheng* 會與舊行程衝突；改產品前綴
for old, new in [
    ("AppleSuChengReloadNotification", "AppleSuChengReloadNotification"),
    ("AppleSuChengSyncNotification", "AppleSuChengSyncNotification"),
    ("AppleSuChengToggleASCIIModeNotification", "AppleSuChengToggleASCIIModeNotification"),
    ("AppleSuChengGetASCIIModeNotification", "AppleSuChengGetASCIIModeNotification"),
    ("AppleSuChengASCIIModeResponse", "AppleSuChengASCIIModeResponse"),
]:
    t = t.replace(old, new)
p.write_text(t, encoding="utf-8")
print("Main.swift OK")
PY

# --- ApplicationDelegate：部署檔名、狀態列 ID 前綴、通知名 ---
python3 - <<PY
from pathlib import Path
p = Path("$FE/sources/AppleSuChengApplicationDelegate.swift")
t = p.read_text(encoding="utf-8")
t = t.replace('deploy_config_file("applesucheng.yaml"', 'deploy_config_file("$UI_YAML"')
t = t.replace('hasPrefix("com.applesucheng.inputmethod.SuCheng")', 'hasPrefix("$BUNDLE_ID")')
for old, new in [
    ("AppleSuChengReloadNotification", "AppleSuChengReloadNotification"),
    ("AppleSuChengSyncNotification", "AppleSuChengSyncNotification"),
    ("AppleSuChengToggleASCIIModeNotification", "AppleSuChengToggleASCIIModeNotification"),
    ("AppleSuChengGetASCIIModeNotification", "AppleSuChengGetASCIIModeNotification"),
    ("AppleSuChengASCIIModeResponse", "AppleSuChengASCIIModeResponse"),
]:
    t = t.replace(old, new)
p.write_text(t, encoding="utf-8")
print("AppleSuChengApplicationDelegate.swift OK")
PY

# --- InputSource：只留繁中（勿保留 Hans，否則 --select 會失敗並搞亂啟用清單）---
python3 - <<PY
from pathlib import Path
import re
p = Path("$FE/sources/InputSource.swift")
t = p.read_text(encoding="utf-8")
t = re.sub(
    r"enum InputMode: String, CaseIterable \{.*?\n  \}",
    '''enum InputMode: String, CaseIterable {
    static let primary = Self.hant
    case hant = "$MODE_HANT"
  }''',
    t,
    count=1,
    flags=re.S,
)
p.write_text(t, encoding="utf-8")
print("InputSource.swift OK (Hant only)")
PY

# --- Info.plist：連線名、Controller、只註冊繁中 ---
# CFBundleIdentifier 由 Xcode PRODUCT_BUNDLE_IDENTIFIER 注入
python3 - <<PY
import plistlib
from pathlib import Path
p = Path("$FE/resources/Info.plist")
info = plistlib.loads(p.read_bytes())
info["TISInputSourceID"] = "$BUNDLE_ID"
info["CFBundleExecutable"] = "$APP_NAME"
info["CFBundleName"] = "$APP_NAME"
info["CFBundleDisplayName"] = "蘋果速成"
info["InputMethodConnectionName"] = "$CONN"
# PRODUCT_NAME=AppleSuCheng 時 Swift 模組名亦為 AppleSuCheng
info["InputMethodServerControllerClass"] = "AppleSuCheng.AppleSuChengInputController"
info["InputMethodServerDelegateClass"] = "AppleSuCheng.AppleSuChengInputController"
info["SUEnableAutomaticChecks"] = False
info.pop("SUFeedURL", None)
hant = {
    "TISInputSourceID": "$MODE_HANT",
    "TISIntendedLanguage": "zh-Hant",
    "TISIconLabels": {"Primary": "速"},
    "tsInputModeIsVisibleKey": True,
    "tsInputModePrimaryInScriptKey": True,
    "tsInputModeDefaultStateKey": True,
    "tsInputModeScriptKey": "smTradChinese",
    "tsInputModeKeyEquivalentKey": "S",
    "tsInputModeKeyEquivalentModifiersKey": 4608,
    "tsInputModeMenuIconFileKey": "sucheng.tiff",
    "tsInputModePaletteIconFileKey": "sucheng.tiff",
    "tsInputModeAlternateMenuIconFileKey": "sucheng.tiff",
    "tsInputModeCharacterRepertoireKey": ["Hant"],
}
info["ComponentInputModeDict"] = {
    "tsInputModeListKey": {"$MODE_HANT": hant},
    "tsVisibleInputModeOrderedArrayKey": ["$MODE_HANT"],
}
p.write_bytes(plistlib.dumps(info))
print("Info.plist OK")
PY

# --- Xcode：Bundle ID、產品名 ---
python3 - <<PY
from pathlib import Path
p = Path("$FE/AppleSuCheng.xcodeproj/project.pbxproj")
t = p.read_text(encoding="utf-8")
t = t.replace("PRODUCT_BUNDLE_IDENTIFIER = com.applesucheng.inputmethod.SuCheng;", "PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE_ID;")
# 執行檔／產品顯示名
t = t.replace("PRODUCT_NAME = AppleSuCheng;", "PRODUCT_NAME = $APP_NAME;")
t = t.replace("path = AppleSuCheng.app;", "path = $APP_NAME.app;")
# Copy File 參照：applesucheng.yaml → applesucheng.yaml
t = t.replace("applesucheng.yaml", "$UI_YAML")
p.write_text(t, encoding="utf-8")
print("project.pbxproj OK")
PY

# --- Makefile 安裝路徑 ---
if [[ -f "$FE/Makefile" ]]; then
  sed -i '' 's|AppleSuCheng\.app|AppleSuCheng.app|g' "$FE/Makefile" || true
fi

# --- 標記已套用 ---
cat > "$FE/PHASE_B_BRANDING.md" <<EOF
# 階段 B 品牌（已套用）

| 項 | 值 |
|----|-----|
| Bundle ID | \`$BUNDLE_ID\` |
| 輸入模式 | \`$MODE_HANT\`（僅繁中） |
| 使用者目錄 | \`~/Library/$USER_DIR_NAME\` |
| 主題檔 | \`SharedSupport/$UI_YAML\` |
| 連線名 | \`$CONN\` |
| Swift 模組／Controller | \`AppleSuCheng.AppleSuChengInputController\` |

上游：見 \`UPSTREAM.md\`（GPL-3.0）。產品方案／Lua 仍在倉庫 \`input-method/\`。
EOF

echo "==> 品牌腳本完成"
