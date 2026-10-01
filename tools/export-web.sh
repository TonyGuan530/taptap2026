#!/usr/bin/env bash
# 本机导出 Web 构建并注册到 Review 站点
# 用法: ./tools/export-web.sh [版本号] [说明] [godot可执行文件]
set -euo pipefail

VERSION="${1:-v$(date +%Y.%m%d-%H%M)}"
NOTES="${2:-}"
GODOT="${3:-godot}"

REPO="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$REPO/builds/$VERSION"
mkdir -p "$BUILD_DIR"

"$GODOT" --headless --path "$REPO/game" --export-release "Web" "$BUILD_DIR/index.html"

cat > "$BUILD_DIR/build.json" <<EOF
{
  "title": "TapTap2026 Demo",
  "version": "$VERSION",
  "date": "$(date +%Y-%m-%dT%H:%M:%S%z)",
  "author": "$(whoami)",
  "notes": "$NOTES"
}
EOF

echo ""
echo "✅ 已导出并注册构建: builds/$VERSION"
echo "   打开 Review 站点（node server/server.js）即可试玩"
