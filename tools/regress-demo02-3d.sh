#!/usr/bin/env bash
# demo-02 3D 一键回归：b 套件 15 案（跨步长自动重试阶梯）+ L7/L8 robustness gate
# 用法：bash tools/regress-demo02-3d.sh [gates]   （在 3D 工作树根目录执行；退出码=失败数）
#   无参=全套（15 案+18 gate 配置）；gates=只跑 18 个 robustness 配置。
#   ⚠️ 实测：同日引擎启动次数累积后启动停振概率上升——b 案跑完后再跑 gate 可能全数假失败；
#   gate 建议单独/清晨/清僵尸+删 .godot 后跑（脚本阶梯含清缓存重试，但重度累积日仍可能连续停振）。
# 阶梯：失败/超时 → 清僵尸重试一次 → 仍失败删 .godot 重建再试一次（硬杀损坏缓存的实测坑）
set -u
GODOT="${GODOT:-/d/GIT/taptap2026/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
LOGD="$APPDATA/Godot/app_userdata/TapTap2026 Demo"
P=0; F=0; FAILED=""

cleanup() {
  taskkill //F //IM Godot_v4.7.2-stable_win64.exe >/dev/null 2>&1
  taskkill //F //IM Godot_v4.7.2-stable_win64_console.exe >/dev/null 2>&1
}

run_case() {  # $1=script(res://...) $2=extra args $3=timeout
  rm -f "$LOGD/v3d_b_log.txt" "$LOGD/v3d_r7_log.txt" "$LOGD/v3d_r8_log.txt"
  timeout "$3" "$GODOT" --headless --path game -s "$1" $2 > /dev/null 2>&1
}

run_with_ladder() {  # $1=script $2=extra args $3=timeout $4=label
  local ec
  run_case "$1" "$2" "$3"; ec=$?
  if [ "$ec" != "0" ]; then
    cleanup; sleep 3
    run_case "$1" "$2" "$3"; ec=$?
    if [ "$ec" != "0" ]; then
      cleanup; sleep 2; rm -rf game/.godot
      run_case "$1" "$2" "$3"; ec=$?
    fi
  fi
  echo "$4"
  return $ec
}

echo "=== demo-02 3D 回归开始 $(date '+%H:%M:%S') ==="
for c in 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14; do
  if run_with_ladder "res://tests/test_demo02_3d_b.gd" "-- --case=$c" 120 "case$c"; then
    P=$((P+1))
  else
    F=$((F+1)); FAILED="$FAILED b$c"
  fi
done

# L7 robustness：9 配置（单场景单进程，进程内不切步长）
for cfg in "30 stone 0 0" "60 stone 0 0" "120 stone 0 0" "60 stone 0.25 0.15" "60 stone -0.25 -0.15" "30 ball 0 0" "60 ball 0 0" "120 ball 0 0" "60 ball 0.25 0"; do
  set -- $cfg
  if run_with_ladder "res://tests/test_demo02_3d_r7.gd" "-- --ticks=$1 --mode=$2 --dx=$3 --dz=$4" 120 "r7[$1 $2 dx$3]"; then
    P=$((P+1))
  else
    F=$((F+1)); FAILED="$FAILED r7($1 $2)"
  fi
done

# L8 robustness：9 配置
for cfg in "30 smash 0 0" "60 smash 0 0" "120 smash 0 0" "60 smash 0.25 0.15" "60 smash -0.25 -0.15" "30 feather 0 0" "60 feather 0 0" "120 feather 0 0" "60 feather 0.25 0"; do
  set -- $cfg
  if run_with_ladder "res://tests/test_demo02_3d_r8.gd" "-- --ticks=$1 --mode=$2 --dx=$3 --dz=$4" 180 "r8[$1 $2 dx$3]"; then
    P=$((P+1))
  else
    F=$((F+1)); FAILED="$FAILED r8($1 $2)"
  fi
done

cleanup
echo "=== 回归完成：$P pass / $F fail${FAILED:+ （失败:$FAILED）} ==="
exit $F
