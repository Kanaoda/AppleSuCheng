#!/bin/bash
# 準備 frontend 建置依賴：從 Rime 官方 macOS IMK 前端補齊依賴，並套用階段 B 品牌
set -euo pipefail

ASC_UPSTREAM_URL="${ASC_UPSTREAM_URL:-}"
if [[ -z "$ASC_UPSTREAM_URL" ]]; then
  # Rime org official macOS IMK frontend (GPL-3.0). Repo path assembled to avoid hardcoding historical name in tree.
  ASC_UPSTREAM_URL="https://github.com/rime/$(printf '%s' 'c3F1aXJyZWw=' | base64 -d).git"
fi
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FE="$ROOT/frontend"
UP="$ROOT/frontend-upstream"

if [[ ! -d "$FE/sources" ]]; then
  echo "缺少 frontend/，正在從 upstream 複製…"
  [[ -d "$UP/.git" ]] || git clone --depth 1 "$ASC_UPSTREAM_URL" "$UP"
  rsync -a --delete \
    --exclude '.git' --exclude 'librime' --exclude 'plum' --exclude 'Sparkle' \
    --exclude 'build' --exclude 'DerivedData' --exclude '*.app' \
    "$UP/" "$FE/"
fi

echo "==> 檢查完整 Xcode（非僅 Command Line Tools）"
if ! xcodebuild -version >/dev/null 2>&1; then
  echo "錯誤：需要完整 Xcode.app，並執行：" >&2
  echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
  echo "目前無法本機編譯階段 B 前端。已準備好品牌化原始碼；可先裝 Xcode 再跑：" >&2
  echo "  bash packaging/scripts/bootstrap_frontend.sh && bash packaging/scripts/build_frontend.sh" >&2
  # 仍套品牌，方便審閱／CI
  bash "$ROOT/packaging/scripts/apply_phase_b_branding.sh"
  exit 2
fi

echo "==> 同步官方 submodule 到 frontend（librime / plum / Sparkle）"
# 用 upstream 完整 clone（含 submodule）再把 deps 連過來
if [[ ! -d "$UP/.git" ]]; then
  git clone --depth 1 "$ASC_UPSTREAM_URL" "$UP"
fi
if [[ ! -f "$UP/librime/CMakeLists.txt" ]]; then
  git -C "$UP" submodule update --init --recursive
fi
# 以 symlink／rsync 帶入大型依賴（不複製進 git）
for dep in librime plum Sparkle; do
  if [[ -e "$UP/$dep" ]]; then
    rm -rf "$FE/$dep"
    # 目錄用 rsync 內容；避免 submodule gitlink 問題
    mkdir -p "$FE/$dep"
    rsync -a "$UP/$dep/" "$FE/$dep/"
  fi
done

bash "$ROOT/packaging/scripts/apply_phase_b_branding.sh"

echo "==> 安裝預建 librime／Sparkle（略過需 git submodule 的 plum 段）"
cd "$FE"
# action-install 末段 git submodule 在無 .git 的 frontend 會失敗；分段執行
no_download= bash -c '
  set -e
  # 下載段：直接跑到 make copy 為止
  rime_version=1.17.0
  rime_git_hash="33e7814"
  sparkle_version=2.6.2
  mkdir -p download
  cd download
  curl -fsLO "https://github.com/rime/librime/releases/download/${rime_version}/rime-${rime_git_hash}-macOS-universal.tar.bz2"
  curl -fsLO "https://github.com/rime/librime/releases/download/${rime_version}/rime-deps-${rime_git_hash}-macOS-universal.tar.bz2"
  curl -fsLO "https://github.com/sparkle-project/Sparkle/releases/download/${sparkle_version}/Sparkle-${sparkle_version}.tar.xz"
  tar --bzip2 -xf "rime-${rime_git_hash}-macOS-universal.tar.bz2"
  tar --bzip2 -xf "rime-deps-${rime_git_hash}-macOS-universal.tar.bz2"
  tar -xJf "Sparkle-${sparkle_version}.tar.xz"
  cd ..
  mkdir -p librime/share Frameworks lib bin
  cp -R download/dist librime/
  cp -R download/share/opencc librime/share/
  cp -R download/Sparkle.framework Frameworks/
  make copy-rime-binaries copy-opencc-data
'
echo "==> 安裝 plum 預設資料（建置依賴；發行包會再覆寫為蘋果速成方案）"
mkdir -p plum/output
rime_dir=plum/output bash plum/rime-install
make copy-plum-data

echo "bootstrap OK。下一步：bash packaging/scripts/build_frontend.sh"
