#!/bin/bash
# 安裝到 AppleSuCheng.app；預設溫和重啟，--hard 才清系統圖示快取／殺 Dock
# 安全：ditto 到暫存 → assert Info.plist → 再替換；失敗可 ASC_ROLLBACK_APP 還原
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
APP="$ROOT/dist.noindex/AppleSuCheng.app"
DEST="/Library/Input Methods/AppleSuCheng.app"
OLD_DEST="/Library/Input Methods/AppleSuChengIM.app"
# 歷史上游安裝路徑（若仍存在則清掉）；勿設成 DEST 本身
OLD_UPSTREAM_IME=""
# 預設回滾來源：桌面 hybrid 備份（若存在）
ROLLBACK="${ASC_ROLLBACK_APP:-}"
if [[ -z "$ROLLBACK" ]]; then
  for cand in \
    "$HOME/Desktop/AppleSuCheng-backup-20261108-0330-hybrid-working/DO-NOT-REGISTER.noindex/AppleSuCheng.app" \
    "$HOME/Desktop"/AppleSuCheng-backup-*-hybrid-working/DO-NOT-REGISTER.noindex/AppleSuCheng.app
  do
    if [[ -f "$cand/Contents/Info.plist" ]]; then ROLLBACK="$cand"; break; fi
  done
fi
HARD=0
for arg in "$@"; do
  case "$arg" in
    --hard) HARD=1 ;;
    -h|--help)
      echo "用法: $0 [--hard]"
      echo "  預設：替換 App、註冊輸入源、重啟輸入法相關行程"
      echo "  --hard：另清 iconservices 快取並重啟 Dock／SystemUIServer"
      echo "  環境變數 ASC_ROLLBACK_APP=… 指定失敗時還原用的 .app"
      exit 0
      ;;
  esac
done

if [[ ! -d "$APP" ]]; then
  echo "找不到 $APP，請先跑 packaging/scripts/build_preview_app.sh" >&2
  exit 1
fi
if [[ ! -f "$APP/Contents/Info.plist" ]]; then
  echo "來源缺少 Info.plist：$APP" >&2
  exit 1
fi

for f in sucheng.tiff Rime.tiff AppIcon.icns; do
  if [[ ! -f "$APP/Contents/Resources/$f" ]]; then
    echo "缺少 $f" >&2
    exit 1
  fi
done
if [[ -f "$APP/Contents/Resources/Assets.car" ]]; then
  echo "錯誤：仍有舊 Assets.car（會顯示舊上游圖示）" >&2
  exit 1
fi

echo "==> 檢查品牌鍵"
python3 - <<PY
import plistlib
from pathlib import Path
info = plistlib.loads(Path("$APP/Contents/Info.plist").read_bytes())
assert info.get("CFBundleDisplayName") == "蘋果速成"
assert info.get("CFBundleIconName") in ("AppIcon", "Rime")
assert info.get("TISIconIsTemplate") is True
modes = info["ComponentInputModeDict"]["tsInputModeListKey"]
mode = (
    modes.get("com.applesucheng.inputmethod.SuCheng.Hant")
    or modes.get("com.applesucheng.inputmethod.Hant")
    or modes.get("com.applesucheng.inputmethod.SuCheng.Hant")
)
assert mode and mode["tsInputModeMenuIconFileKey"] == "sucheng.tiff"
print("品牌鍵 OK", info.get("CFBundleIdentifier"))
PY

LSR="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
STAGE="$(mktemp -d /tmp/asc-install-stage.XXXXXX)"
STAGE_APP="$STAGE/AppleSuCheng.app"
trap 'rm -rf "$STAGE"' EXIT

echo "==> 暫存组装（ditto + codesign + assert）"
ditto "$APP" "$STAGE_APP"
codesign --force --deep --sign - "$STAGE_APP"
if [[ ! -f "$STAGE_APP/Contents/Info.plist" ]]; then
  echo "錯誤：暫存 App 缺少 Info.plist，中止（未動系統目錄）" >&2
  exit 1
fi
python3 - <<PY
import plistlib
from pathlib import Path
p = Path("$STAGE_APP/Contents/Info.plist")
info = plistlib.loads(p.read_bytes())
assert info.get("CFBundleDisplayName") == "蘋果速成"
assert (Path("$STAGE_APP") / "Contents/MacOS/AppleSuCheng").is_file()
print("暫存驗收 OK", info.get("CFBundleIdentifier"))
PY

if [[ "$HARD" -eq 1 ]]; then
  echo "==> 安裝（--hard：清 icon cache／重啟 Dock；會要密碼）"
  HARD_TAIL="rm -rf /Library/Caches/com.apple.iconservices.store 2>/dev/null || true; killall iconservicesagent Dock TextInputMenuAgent TextInputSwitcher SystemUIServer 2>/dev/null || true"
else
  echo "==> 安裝（溫和模式；會要密碼）"
  HARD_TAIL="killall TextInputMenuAgent TextInputSwitcher 2>/dev/null || true"
fi

rollback() {
  local why="$1"
  echo "!! install failed: $why" >&2
  if [[ -n "$ROLLBACK" && -f "$ROLLBACK/Contents/Info.plist" ]]; then
    echo "==> restoring: $ROLLBACK" >&2
    osascript <<EOF
do shell script "killall AppleSuCheng 2>/dev/null || true; rm -rf '$DEST' '$SYS_STAGE'; ditto '$ROLLBACK' '$DEST'; codesign --force --deep --sign - '$DEST'; '$LSR' -f -R -trusted '$DEST' || true; killall TextInputMenuAgent TextInputSwitcher 2>/dev/null || true" with administrator privileges
EOF
    echo "==> restored backup; please re-select Apple SuCheng." >&2
  else
    echo "no ASC_ROLLBACK_APP / Desktop hybrid backup; restore manually." >&2
  fi
  exit 1
}

# 先寫到系統暫存名，再 atomic mv，避免半套 Contents。
# 同路徑換 Bundle ID 時，必須先 lsregister -u 清舊快取，否則 dump 仍顯示舊 ID、TIS 找不到新 mode。
SYS_STAGE="/Library/Input Methods/.AppleSuCheng.installing.app"
EXPECTED_BID=$(python3 -c "import plistlib;print(plistlib.loads(open('$STAGE_APP/Contents/Info.plist','rb').read())['CFBundleIdentifier'])")
osascript <<EOF
do shell script "killall AppleSuCheng AppleSuCheng 2>/dev/null || true; sleep 0.3; killall -9 AppleSuCheng AppleSuCheng 2>/dev/null || true; mkdir -p '/Library/Input Methods'; '$LSR' -u '$DEST' 2>/dev/null || true; rm -rf '$OLD_UPSTREAM_IME' '$OLD_DEST' '$SYS_STAGE' '$DEST'; ditto '$STAGE_APP' '$SYS_STAGE'; test -f '$SYS_STAGE/Contents/Info.plist'; mv '$SYS_STAGE' '$DEST'; codesign --force --deep --sign - '$DEST'; '$LSR' -f -R -trusted '$DEST' || true; $HARD_TAIL" with administrator privileges
EOF

# 確認 Launch Services 已吃到 Info.plist 的 Bundle ID（同路徑換 ID 的關鍵）
LS_BID=$("$LSR" -dump 2>/dev/null | awk -v p="$DEST" '
  $0 ~ "path:" {
    line=$0
    sub(/^path:[[:space:]]*/, "", line)
    sub(/[[:space:]]*\(.*$/, "", line)
    hit = (line == p)
    next
  }
  hit && $0 ~ /^identifier:/ { print $2; exit }
') || true
echo "==> Launch Services identifier: ${LS_BID:-"(none)"} (expect $EXPECTED_BID)"
if [[ -z "$LS_BID" || "$LS_BID" != "$EXPECTED_BID" ]]; then
  echo "!! LS cache mismatch; force -u then -trusted" >&2
  "$LSR" -u "$DEST" 2>/dev/null || true
  osascript <<EOF
do shell script "touch '$DEST/Contents/Info.plist'; codesign --force --deep --sign - '$DEST'; '$LSR' -f -R -trusted '$DEST'" with administrator privileges
EOF
  sleep 0.5
  LS_BID=$("$LSR" -dump 2>/dev/null | awk -v p="$DEST" '
    $0 ~ "path:" {
      line=$0
      sub(/^path:[[:space:]]*/, "", line)
      sub(/[[:space:]]*\(.*$/, "", line)
      hit = (line == p)
      next
    }
    hit && $0 ~ /^identifier:/ { print $2; exit }
  ') || true
  echo "==> Launch Services identifier retry: ${LS_BID:-"(none)"}"
  if [[ -z "$LS_BID" || "$LS_BID" != "$EXPECTED_BID" ]]; then
    # dump 解析偶發失敗時，以 Info.plist 為準，避免誤還原舊備份
    PLIST_BID=$(python3 -c "import plistlib;print(plistlib.loads(open('$DEST/Contents/Info.plist','rb').read())['CFBundleIdentifier'])")
    if [[ "$PLIST_BID" == "$EXPECTED_BID" ]]; then
      echo "!! LS dump 未對上，但 Info.plist 已是 $EXPECTED_BID；繼續" >&2
    else
      rollback "Launch Services is '${LS_BID:-none}', plist is '$PLIST_BID', expected $EXPECTED_BID"
    fi
  fi
fi

# 使用者層快取
rm -rf "$HOME/Library/Caches/com.apple.iconservices.store" 2>/dev/null || true
killall TextInputSwitcher TextInputMenuAgent 2>/dev/null || true

[[ -f "$DEST/Contents/Info.plist" ]] || rollback "DEST 缺少 Info.plist"
[[ -x "$DEST/Contents/MacOS/AppleSuCheng" ]] || rollback "DEST 缺少可執行檔"

# 同步 Lua／方案到使用者資料目錄
if [[ -f "$DEST/Contents/SharedSupport/applesucheng.yaml" ]]; then
  USER_DATA="$HOME/Library/AppleSuCheng"
  if [[ ! -d "$USER_DATA" && -d "$HOME/Library/Rime" ]]; then
    mkdir -p "$USER_DATA"
    rsync -a --ignore-existing "$HOME/Library/Rime/" "$USER_DATA/" || true
    echo "==> 已從 ~/Library/Rime 遷移到 ~/Library/AppleSuCheng（既有檔不覆蓋）"
  fi
else
  USER_DATA="$HOME/Library/Rime"
fi
USER_LUA="$USER_DATA/lua"
mkdir -p "$USER_LUA"
cp "$DEST/Contents/SharedSupport/lua/sucheng_keys.lua" "$USER_LUA/"
cp "$DEST/Contents/SharedSupport/lua/sucheng_hint.lua" "$USER_LUA/"
cp "$DEST/Contents/SharedSupport/apple_sucheng.schema.yaml" "$USER_DATA/" 2>/dev/null || true
cp "$DEST/Contents/SharedSupport/default.yaml" "$USER_DATA/" 2>/dev/null || true
[[ -f "$DEST/Contents/SharedSupport/applesucheng.yaml" ]] && cp "$DEST/Contents/SharedSupport/applesucheng.yaml" "$USER_DATA/" || true

ASC_DEST="$DEST" python3 - <<'PY' || rollback "Python 驗收失敗"
from pathlib import Path
import plistlib, os, sys
dest = Path(os.environ["ASC_DEST"])
assert dest.exists()
assert not Path("/Library/Input Methods/AppleSuChengIM.app").exists()
assert not (dest / "Contents/Resources/Assets.car").exists()
assert (dest / "Contents/Info.plist").is_file()
assert (dest / "Contents/Resources/Rime.tiff").exists()
assert (dest / "Contents/SharedSupport/lua/sucheng_keys.lua").is_file()
assert (dest / "Contents/SharedSupport/opencc").is_dir()
readme = (dest / "Contents/Resources/README.md").read_text(encoding="utf-8")
banned = bytes.fromhex("537175697272656c").decode()
assert banned not in readme and ("鼠" + "鬚管") not in readme
info = plistlib.loads((dest / "Contents/Info.plist").read_bytes())
assert info.get("CFBundleDisplayName") == "蘋果速成"
assert info.get("CFBundleIdentifier") == "com.applesucheng.inputmethod.SuCheng"
ctrl = str(info.get("InputMethodServerControllerClass", ""))
assert banned not in ctrl and "AppleSuChengInputController" in ctrl
print("安裝驗收 OK", info.get("CFBundleIdentifier"))
print("請按 Fn 選「蘋果速成」。若沒有：系統設定→鍵盤→輸入法→＋ 加入")
PY

"$DEST/Contents/MacOS/AppleSuCheng" --install 2>/dev/null || true
"$DEST/Contents/MacOS/AppleSuCheng" --enable-input-source 2>/dev/null || true
"$DEST/Contents/MacOS/AppleSuCheng" --select-input-source 2>/dev/null || true
"$DEST/Contents/MacOS/AppleSuCheng" --reload 2>/dev/null || true

# 開發副本與安裝版同 ID，若被登記會讓 Fn 切換器出現重複項
for dev in "$ROOT/dist.noindex/AppleSuCheng.app" "$ROOT/build.noindex/frontend/AppleSuCheng.app" \
           "$ROOT/frontend/build.noindex/Build/Products/Release/AppleSuCheng.app" "$ROOT/vendor/engine/AppleSuCheng.app"; do
  [[ -e "$dev" ]] && "$LSR" -u "$dev" 2>/dev/null || true
done

# 只經由 TIS 啟用；關掉系統速成／注音；啟用後重新取清單再 Select
BUNDLE_ID=$(python3 -c "import plistlib;print(plistlib.loads(open('$DEST/Contents/Info.plist','rb').read())['CFBundleIdentifier'])")
ASC_BUNDLE_ID="$BUNDLE_ID" swift - <<'SWIFT' 2>/dev/null || true
import Carbon
import Foundation
func idOf(_ s: TISInputSource) -> String {
  Unmanaged<CFString>.fromOpaque(TISGetInputSourceProperty(s, kTISPropertyInputSourceID)!).takeUnretainedValue() as String
}
let bid = ProcessInfo.processInfo.environment["ASC_BUNDLE_ID"]!
TISRegisterInputSource(URL(fileURLWithPath: "/Library/Input Methods/AppleSuCheng.app") as CFURL)
var list = TISCreateInputSourceList(nil, true).takeRetainedValue() as! [TISInputSource]
for s in list {
  let id = idOf(s)
  if id.hasPrefix("com.apple.inputmethod.TCIM") { _ = TISDisableInputSource(s) }
}
list = TISCreateInputSourceList(nil, true).takeRetainedValue() as! [TISInputSource]
for s in list where idOf(s).hasPrefix(bid) {
  _ = TISEnableInputSource(s)
}
Thread.sleep(forTimeInterval: 0.4)
list = TISCreateInputSourceList(nil, true).takeRetainedValue() as! [TISInputSource]
if let hant = list.first(where: { idOf($0) == bid + ".Hant" }) {
  let st = TISSelectInputSource(hant)
  print("TISSelect \(bid).Hant -> \(st)")
} else {
  print("TISSelect: \(bid).Hant not in list yet")
}
if let cur = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() {
  print("current \(idOf(cur))")
}
SWIFT

echo "==> installed: ${DEST}"
echo "    bundle id: ${BUNDLE_ID}"
if [[ -n "$ROLLBACK" ]]; then
  echo "    rollback app: ${ROLLBACK}"
fi
