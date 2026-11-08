#!/bin/bash
# 產出一般用戶 Release 安裝包（zip）：含 .app + 雙擊安裝腳本 + 說明
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DIST="$ROOT/dist.noindex"
APP="$DIST/AppleSuCheng.app"
REL_ROOT="$DIST/release"
VERSION="${ASC_RELEASE_VERSION:-}"

if [[ ! -d "$APP" || ! -f "$APP/Contents/Info.plist" ]]; then
  echo "找不到已打包的 $APP" >&2
  echo "請先：ASC_PHASE_B=1 bash packaging/scripts/build_preview_app.sh" >&2
  exit 1
fi

if [[ -z "$VERSION" ]]; then
  VERSION="$(plutil -extract CFBundleShortVersionString raw "$APP/Contents/Info.plist" 2>/dev/null || echo 0.0.0)"
fi

STAGE_NAME="AppleSuCheng-${VERSION}-macOS"
STAGE="$REL_ROOT/$STAGE_NAME"
ZIP="$REL_ROOT/${STAGE_NAME}.zip"

echo "==> Release $VERSION"
rm -rf "$STAGE"
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/AppleSuCheng.app"

# 雙擊安裝（不需 clone 倉庫）
cat > "$STAGE/安裝.command" <<'EOS'
#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
APP="$(pwd)/AppleSuCheng.app"
DEST="/Library/Input Methods/AppleSuCheng.app"

if [[ ! -d "$APP" || ! -f "$APP/Contents/Info.plist" ]]; then
  osascript -e 'display alert "找不到 AppleSuCheng.app" message "請確認與此安裝程式放在同一資料夾。" as critical'
  exit 1
fi

osascript <<APPLESCRIPT
do shell script "ditto " & quoted form of "$APP" & " " & quoted form of "$DEST" & " && chown -R root:wheel " & quoted form of "$DEST" & " && xattr -dr com.apple.quarantine " & quoted form of "$DEST" & " ; /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f " & quoted form of "$DEST" & " ; killall -9 AppleSuCheng 2>/dev/null || true ; killall TextInputMenuAgent TextInputSwitcher 2>/dev/null || true" with administrator privileges
APPLESCRIPT

osascript -e 'display dialog "蘋果速成已安裝。\n\n請打開「系統設定 → 鍵盤 → 輸入法」，加入「蘋果速成」，即可開始使用。\n若列表尚未出現，登出再登入一次。" buttons {"完成"} default button 1 with title "蘋果速成"'
open "x-apple.systempreferences:com.apple.Keyboard-Settings.extension"
EOS
chmod +x "$STAGE/安裝.command"

cat > "$STAGE/安裝說明.txt" <<EOF
蘋果速成 / Apple SuCheng ${VERSION}
================================

這是給一般用戶的 macOS 安裝包（Apple Silicon / Intel 視此建置架構而定）。

安裝步驟
--------
1. 若從網際網路下載，先對資料夾／zip 按右鍵 →「打開」（或在「隱私權與安全性」允許）。
2. 雙擊「安裝.command」，輸入本機密碼。
3. 打開「系統設定 → 鍵盤 → 輸入法」→「＋」→ 加入「蘋果速成」。
4. 選單列應出現灰底白字「速」。

若打不出字
----------
- 確認已加入並切換到「蘋果速成」
- 登出再登入（或重開機）一次
- 仍不行：刪除「/Library/Input Methods/AppleSuCheng.app」後重新執行安裝

支援
----
作者：Kanaoda
GitHub Sponsors：https://github.com/sponsors/Kanaoda
Buy Me a Coffee：https://buymeacoffee.com/kanaoda

授權：產品方案／腳本 MIT；輸入法前端為 GPL-3.0 元件（見 App 內 NOTICE／LICENSE）。
EOF

# 輕量驗收
python3 - <<PY
import plistlib
from pathlib import Path
app = Path("$STAGE/AppleSuCheng.app")
info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
assert info.get("CFBundleDisplayName") == "蘋果速成"
assert info.get("CFBundleIdentifier") == "com.applesucheng.inputmethod.SuCheng"
assert (app / "Contents/MacOS/AppleSuCheng").is_file()
assert (app / "Contents/SharedSupport/applesucheng.yaml").is_file()
assert (app / "Contents/Resources/sucheng.tiff").is_file()
print("release app OK", info.get("CFBundleShortVersionString"), info.get("CFBundleIdentifier"))
PY

rm -f "$ZIP"
# 去掉 AppleDouble/资源叉，避免 zip 內出現 ._ 檔
find "$STAGE" -name '._*' -delete
find "$STAGE" -name '.DS_Store' -delete
(
  cd "$REL_ROOT"
  COPYFILE_DISABLE=1 zip -ry "$ZIP" "$STAGE_NAME" -x '*/.*' '*/._*'
)

echo "==> 完成"
echo "資料夾：$STAGE"
echo "壓縮包：$ZIP"
ls -lh "$ZIP"
