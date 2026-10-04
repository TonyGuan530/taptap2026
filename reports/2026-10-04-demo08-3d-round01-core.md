# demo-08 3D 迁移 · 第 1 轮（阶段 A 第一切片：规则核心提取与新旧对照）

日期：2026-10-04。执行：demo-08 专属定时任务 automation-1d162838 首个开发轮。

## 本轮完成

1. **基线修复与确认**：新 worktree 缺 `.godot` 导入缓存导致旧测试假绿（脚本加载失败但退出码 0）。补 `--import` 后旧版 `tests/test_demo08.gd` 真实通过：**9 PASS / 0 FAIL**（退出码 0）。
2. **规则核心提取**（新文件 `game/demo08_3d/flight_core.gd`，RefCounted，旧 px 单位）：
   - 折线参数汇总（外升力/上配平/长阻力）、投掷冻结（eff_lift、40° 容错）、纵向积分（升力封顶 0.95g、速度²阻力、风、螺旋桨、机头追随）、高低门（互斥、即时入 coins）、终点>落地（韧性一次）>14 秒超时优先级、经济（int(d/10)+固定奖励）、商店（≤3 件、购后移出、唯一不重现、线性叠加）。
   - 全部公式与 `demo08_paperplane.gd` 逐行等价；折线上限/纸外 10px 容差保留；含归一参数入口 `apply_fold_params(out, vert, len_c)` 供后续 3D 折纸 UI。
   - 新增（非经济变更）：`gate_coins` 单独累计本掷门奖，供结算显示拆分（旧版 coins_earned 被结算覆盖漏显门奖的问题在表现层解决）。
3. **对照与不变量测试**（新文件 `game/tests/test_demo08_3d.gd`，固定 delta=1/60、time_scale=1，退出码失败非零）：
   - A 组新旧对照：L1 无风 30°、L2 逆风 42°（自然命中高门，币数 13 一致）、L3 顺风 35°、L1 全强化（力气2/翼面1/螺旋桨/配平仪）、超时、终点>落地、韧性弹跳——**逐步轨迹逐点一致**（1e-6 px），距离/币数/门/顶点一致。
   - B 组不变量：折线上限与纸外拒绝、参数方向、阻力=0.18×长度比、角度容错（40°=0.20/35°=0/30°=0/抬头=0）、门互斥与即时到账、25 种子抽池唯一不重现、价格升序、买后移出、力度 1+0.2n 线性、余额不足拒绝、流转与解锁、reset 清空。
   - 结果：**55 PASS / 0 FAIL**（退出码 0）。2D 对照文件未动一行。

## 证据

- 旧基线：`==== 汇总：9 PASS / 0 FAIL ====`（/tmp/t08_base2.log，本报告写就时已复跑两次均绿）
- 新核心：`结果：PASS 55 · FAIL 0`，EXIT=0（/tmp/t08_3d.log）
- 运行命令：`tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path D:/GIT/taptap2026-demo08-3d/game --import` 然后 `-s res://tests/test_demo08*.gd`（Godot 4.7.2，worktree 未提交二进制，共用主仓库捆绑版）

## Miro / 反馈

- Miro：无 demo-08 新想法（backlog 已收录原贴纸 @(1340,16707)）；同步由主仓库 pipeline-lite（5 分钟）负责，本轮未重复抓取（worktree 无 token/data）。
- 玩家反馈：未发现 demo-08 相关新评论。

## 未做 / 待办（下轮）

- 发布：无（尚无 3D 场景与可玩增量，未触发发布条件）；demos.json 不变。
- ChatGPT 评审：demo-08-3d 专属评审对话未建立，列为待办（有可玩灰模后一并送评）。
- **下一轮：阶段 A 第二切片** —— `game/demo08_3d.tscn` 灰模：Node3D 根 + 地面/门/终点三维表现（60px=1m，-Z 前进）+ CameraRig→SpringArm3D→Camera3D 跟随机位 + HUD Control（折纸/投掷/结算/商店）+ 真实点击与按键可完成 L1 完整局；MCP Pro 连接本 worktree 后做输入与截图验证。

## 已知坑记录

- 新 worktree 首次跑测试必须先 `--import`，否则 preload 失败且退出码仍为 0（假绿）。
- shell 管道 `cmd | tail` 会吃掉 Godot 退出码，验证必须 `cmd > log 2>&1; echo $?`。
- 旧版门判定是"跨线后单帧位置"口径（prev_x < gate_px ≤ x，高度取跨线后值）；核心按此口径等价迁移。阶段 B 三维门改线段求交+交点高度时，作为新增检测口径单独记录，不混入对照核心。
