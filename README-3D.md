# demo-04 3D（SOUP 2.0 DNA 融合逃生 · 第三人称）操作手册

> 本分支 = demo04-3d worktree（D:\GIT\taptap2026-demo04-3d）。2D v12 冻结基线见主仓库 main。
> 阶段总览：reports/demo04-3d-stage-report.md（四阶段验收对照，单一入口）。

## 试玩
- Web（恒新）：https://tonyguan530.github.io/taptap2026/builds/demo-04-3d-v13/index.html
- 原生：builds/native/demo04_3d.exe（本地产物，不入库）

## 操作
| 键 | 作用 |
| --- | --- |
| WASD / 方向键 | 移动 |
| Space | 跳（二段跳需振翅 DNA；长按不吞二段） |
| E | 与外星生物融合（靠近出现提示） |
| R / Shift+R | 重开本关 / 完整再跑（清全部进度） |
| H | 隐藏/显示屏幕底部键位条 |
| K / B | 进出实验房（全 DNA；实验房内 1~5 直达关卡） |
| G / T | 切被试编号（P1~P5）/ 导出遥测（下载 + IndexedDB 双写） |

## DNA（每关重教，组合发现跨关保留）
弹簧腿（高跳×1.45）· 振翅（二段×0.95）· 荧光（暗区恢复速度）· 碎岩（撞裂纹墙即碎）
组合：超级弹跳=弹簧腿+振翅 · 夜翼=振翅+荧光（仅发现显示，无增益）

## 开发
```
# 3D 套件（25 项断言，失败退出非零）
tools godot:  godot --headless --path game -s res://tests/test_demo04_3d.gd
# 2D 冻结基线回归（7 用例）
godot --headless --path game -s res://tests/test_demo04.gd
# 五关巡游机器人（真实输入全通验证）
godot --headless --path game res://tests/movie_demo04_3d.tscn
# 导出 Web（导出后必须核对 pck）
godot --headless --path game --export-release "Web" ../builds/demo-04-3d-vN/index.html
node tools/verify-pck-demo04-3d.mjs builds/demo-04-3d-vN
```

## 无窗口录证管线（用户红线：禁止抢鼠标/开窗）
- 截图：`node tools/cdp-shot-demo04-3d.mjs`（Edge headless + CDP 前台模拟）
- 演示片：`node tools/cdp-tour-video.mjs builds/demo-04-3d-vN`（?tour=1 内置巡游 → captureScreenshot 轮询 → ffmpeg）
- Web 验收：`node tools/cdp-webcheck-demo04-3d.mjs`（iframe/遥测下载落地/实验房）
- ⚠️ Miro v1 API：GET 列表返回无内容的桩，检索必须单件 GET；文本在顶层 `text` 字段

## 代码结构（game/demo04_3d/）
root.gd（LEVELS 数据驱动五关+实验房+遥测）· player.gd（CharacterBody3D，DNA 语义对齐 2D）·
ability_state.gd（DNA 参数）· camera_rig.gd（跟随）· tour_driver.gd（?tour=1 显式巡游组件）

## 关键规则（3D 适配，详见 physics-baseline.md）
裂纹墙顶 2.9m（碎岩唯一解）· 上层捷径=西侧空中栈道（组合独占）· 弹跳板 z 侧带（纯可选）·
掉坑回此前安全落点（保留 DNA/碎墙/碎片，计时继续）· 评级 ≤45s S / ≤90s A
