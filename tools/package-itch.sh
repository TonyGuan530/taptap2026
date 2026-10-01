#!/usr/bin/env bash
# 打包 itch.io 上传用的 zip（HTML 项目）
# 用法: ./tools/package-itch.sh [版本号]   （不带参数 = 自动取最新构建）
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
BUILDS="$REPO/builds"

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
  VERSION="$(ls -1t "$BUILDS" | while read -r d; do
    [ -f "$BUILDS/$d/index.html" ] && echo "$d" && break
  done)"
  [ -n "$VERSION" ] || { echo "builds/ 下没有可用构建"; exit 1; }
fi

mkdir -p "$REPO/dist-itch"
( cd "$BUILDS/$VERSION" && zip -qr "$REPO/dist-itch/$VERSION.zip" . )

echo ""
echo "✅ 已生成: dist-itch/$VERSION.zip"
echo ""
echo "itch.io 上传步骤:"
echo "  1. https://itch.io/game/new"
echo "  2. Kind of project: HTML"
echo "  3. 上传 zip，勾选 'This file will be played in the browser'"
echo "  4. Viewport: 960 x 540"
echo "  5. Save & view page → 立即公开，无需审核"
