#!/bin/bash
# 自產「速」圖示（不散佈 Apple TCIM sucheng.tiff）
# 可選：ASC_USE_SYSTEM_TIFF=1 僅本機對照用，勿用於發行包
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ASSETS="$ROOT/website/assets"
mkdir -p "$ASSETS"
export ASC_ASSETS="$ASSETS"

NATIVE="/System/Library/Input Methods/TCIM.app/Contents/PlugIns/TCIM_Extension.appex/Contents/Resources/sucheng.tiff"
ALT="/System/Library/Input Methods/TYIM.app/Contents/PlugIns/TYIM_Extension.appex/Contents/Resources/sucheng.tiff"

if [[ "${ASC_USE_SYSTEM_TIFF:-0}" == "1" ]]; then
  if [[ -f "$NATIVE" ]]; then
    cp "$NATIVE" "$ASSETS/sucheng_system_template.tiff"
  elif [[ -f "$ALT" ]]; then
    cp "$ALT" "$ASSETS/sucheng_system_template.tiff"
  else
    echo "ASC_USE_SYSTEM_TIFF=1 但找不到系統 sucheng.tiff" >&2
    exit 1
  fi
  echo "（本機對照）已存 sucheng_system_template.tiff；發行圖示仍用自產"
fi

python3 <<'PY'
from PIL import Image, ImageDraw, ImageFont
import os, struct, subprocess, tempfile, shutil

assets = os.environ["ASC_ASSETS"]
font_path = next(p for p in [
    "/System/Library/Fonts/STHeiti Medium.ttc",
    "/System/Library/Fonts/STHeiti Light.ttc",
    "/System/Library/Fonts/PingFang.ttc",
] if os.path.exists(p))

PLATE = (90, 90, 92, 255)
WHITE = (255, 255, 255, 255)

def font_for(size: int):
    return ImageFont.truetype(font_path, max(8, int(size * 0.72)), index=0)

def draw_su(size: int, *, plate=True) -> Image.Image:
    """灰底圓角 + 白「速」（Fn／選單／App 圖）"""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if plate:
        d.rounded_rectangle(
            [0, 0, size - 1, size - 1],
            radius=max(2, size * 22 // 100),
            fill=PLATE,
        )
    f = font_for(size)
    bb = d.textbbox((0, 0), "速", font=f)
    tw, th = bb[2] - bb[0], bb[3] - bb[1]
    d.text(
        ((size - tw) / 2 - bb[0], (size - th) / 2 - bb[1] - size * 0.04),
        "速",
        font=f,
        fill=WHITE,
    )
    return img

def draw_template(size: int) -> Image.Image:
    """近似系統 template：透明底 + 深色「速」字形（可被系統上色）"""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    f = font_for(size)
    bb = d.textbbox((0, 0), "速", font=f)
    tw, th = bb[2] - bb[0], bb[3] - bb[1]
    # 黑墨 + alpha，供 TIS template 上色
    d.text(
        ((size - tw) / 2 - bb[0], (size - th) / 2 - bb[1] - size * 0.04),
        "速",
        font=f,
        fill=(0, 0, 0, 255),
    )
    return img

def write_hidpi_tiff(path16: str, path32: str, out_tiff: str):
    """必須 16@72dpi + 32@144dpi。tiffutil -cathidpicheck 要檔名含 @2x 才會保留 144 DPI。"""
    t16, t32 = "/tmp/asc_icon.tiff", "/tmp/asc_icon@2x.tiff"
    for src, dst, dpi in ((path16, t16, 72), (path32, t32, 144)):
        subprocess.check_call([
            "sips", "-s", "format", "tiff",
            "-s", "dpiWidth", str(dpi), "-s", "dpiHeight", str(dpi),
            src, "--out", dst,
        ], stdout=subprocess.DEVNULL)
    subprocess.check_call(["tiffutil", "-cathidpicheck", t16, t32, "-out", out_tiff])
    info = subprocess.check_output(["tiffutil", "-info", out_tiff], text=True)
    res = [ln.strip() for ln in info.splitlines() if "Resolution:" in ln]
    if len(res) < 2 or "72, 72" not in res[0] or "144, 144" not in res[1]:
        raise SystemExit(f"HiDPI TIFF 不合格（需 72 然後 144）: {res}")

# --- 選單／Fn：灰階 template（TISIconIsTemplate=true；游標旁小提示才是系統原生樣）---
t16 = os.path.join(assets, "su_template_16.png")
t32 = os.path.join(assets, "su_template_32.png")
draw_template(16).convert("LA").save(t16)
draw_template(32).convert("LA").save(t32)
write_hidpi_tiff(t16, t32, os.path.join(assets, "sucheng.tiff"))
shutil.copy(os.path.join(assets, "sucheng.tiff"), os.path.join(assets, "sucheng_menu.tiff"))
shutil.copy(os.path.join(assets, "sucheng.tiff"), os.path.join(assets, "sucheng_own_template.tiff"))
shutil.copy(os.path.join(assets, "sucheng.tiff"), os.path.join(assets, "Rime.tiff"))
shutil.copy(os.path.join(assets, "sucheng.tiff"), os.path.join(assets, "icon.tiff"))

# 灰底白字彩圖：網站／AppIcon 用，不進輸入法選單鍵
p16 = os.path.join(assets, "menu_su_16.png")
p32 = os.path.join(assets, "menu_su_32.png")
draw_su(16).save(p16)
draw_su(32).save(p32)
draw_su(128).save(os.path.join(assets, "menu_su_128.png"))
write_hidpi_tiff(p16, p32, os.path.join(assets, "sucheng_menu_color.tiff"))

# --- AppIcon.icns + logo ---
tmp = tempfile.mkdtemp()
iconset = os.path.join(tmp, "AppIcon.iconset")
os.makedirs(iconset)
files = [
    (16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png"),
]
icns_map = [
    ("icp4", "icon_16x16.png"), ("ic11", "icon_16x16@2x.png"),
    ("icp5", "icon_32x32.png"), ("ic12", "icon_32x32@2x.png"),
    ("ic07", "icon_128x128.png"), ("ic13", "icon_128x128@2x.png"),
    ("ic08", "icon_256x256.png"), ("ic14", "icon_256x256@2x.png"),
    ("ic09", "icon_512x512.png"), ("ic10", "icon_512x512@2x.png"),
]
for sz, name in files:
    draw_su(sz).save(os.path.join(iconset, name))
    if sz in (16, 32, 64, 128, 256, 512, 1024):
        draw_su(sz).save(os.path.join(assets, f"su_{sz}.png"))
parts = []
for ostype, fname in icns_map:
    data = open(os.path.join(iconset, fname), "rb").read()
    parts.append(ostype.encode() + struct.pack(">I", len(data) + 8) + data)
body = b"".join(parts)
open(os.path.join(assets, "AppIcon.icns"), "wb").write(b"icns" + struct.pack(">I", len(body) + 8) + body)
draw_su(256).save(os.path.join(assets, "logo.png"))
subprocess.check_call(
    ["sips", "-s", "format", "pdf", os.path.join(assets, "logo.png"), "--out", os.path.join(assets, "logo.pdf")],
    stdout=subprocess.DEVNULL,
)
print("自產「速」圖示 OK（未散佈 Apple TCIM TIFF）")
PY

echo "sucheng.tiff / Rime.tiff / AppIcon => 自產灰底白字「速」（正確 HiDPI）"
file "$ASSETS/sucheng.tiff" "$ASSETS/sucheng_menu_color.tiff" "$ASSETS/AppIcon.icns"
# 確認不是系統 byte 副本
if [[ -f "$NATIVE" ]] && cmp -s "$ASSETS/sucheng.tiff" "$NATIVE"; then
  echo "錯誤：sucheng.tiff 仍與系統 TCIM 相同" >&2
  exit 1
fi
echo "圖示授權：自產（非 Apple 資源複製）"
