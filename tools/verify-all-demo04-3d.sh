#!/bin/bash
# demo-04 3D 一键全量验证：3D 套件 → 2D 冻结基线 → 巡游机器人 → 混沌浸泡
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# 用法：bash tools/verify-all-demo04-3d.sh [game目录] [混沌秒数，0=跳过]
set -e
GAME="${1:-$(dirname "$0")/../game}"
CHAOS="${2:-120}"
GODOT="${GODOT:-/d/GIT/taptap2026/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
cd "$GAME"
echo "==== 1/4 3D 套件（25+ 项断言）===="
"$GODOT" --headless --path . -s res://tests/test_demo04_3d.gd > /tmp/d04suite.log 2>&1
grep -E "RESULTS|ALL PASS|FAILED" /tmp/d04suite.log
grep -q "ALL PASS" /tmp/d04suite.log || { echo "FAIL: 3D 套件"; exit 1; }
echo "==== 2/4 2D 冻结基线（7 用例）===="
"$GODOT" --headless --path . -s res://tests/test_demo04.gd 2>&1 | grep -cE "PASS" | xargs -I{} echo "PASS 行数: {}"
echo "==== 3/4 五关巡游机器人 ===="
"$GODOT" --headless --path . res://tests/movie_demo04_3d.tscn 2>&1 | grep -E "TOUR DONE|ALL PASS"
echo "==== 4/4 混沌浸泡（${CHAOS}s，0 跳过）===="
if [ "$CHAOS" != "0" ]; then
  BUILD_DIR="../builds/demo-04-3d-v10"; [ -d "$BUILD_DIR" ] || BUILD_DIR="../builds/demo-04-3d-v9"
  node "$SCRIPT_DIR/cdp-chaos-demo04-3d.mjs" "$BUILD_DIR" "$CHAOS" || { echo "FAIL: 混沌浸泡"; exit 1; }
fi
echo "==== 全量验证通过 ===="
