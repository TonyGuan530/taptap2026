# demo-08 3D 迁移 · 第 2 轮（阶段 A 切片 2：三维跟随灰模，真实输入完整局）

日期：2026-10-04。执行：demo-08 定时任务 automation-1d162838。

## 本轮完成

1. **3D 灰模场景**（新文件 `game/demo08_3d.tscn` + `game/demo08_3d/demo08_3d.gd`，纯代码构建，无外部素材）：
   - 世界：程序化天空 + 平行光 + 地面/跑道/起点台；终点旗门（柱+横幅+地线）；L2/L4/L5 的高门圆环（12m）与低门横杆（10m）按关卡重建；飞行轨迹 3D 折线。
   - 坐标契约落地：`world=(0,(460-old_y)/60,-(old_x-60)/60)`，X 侧向恒 0（阶段 A 受限轨迹桥梁）、Y 向上、前进 -Z；飞机网格本地机头 -Z，俯仰用 `-pitch` 表现，不引入横向自由度。
   - 相机：`CameraRig→SpringArm3D(8m, -14°)→Camera3D` 跟随机位，位于飞机后上方、不继承滚转、R 键复位；镜头状态与模拟零耦合（测试 S7 证明）。
   - HUD（CanvasLayer+Control）：选关/折纸纸面（真实两点成线）/三参数档位/投掷角与蓄力条/结算（**门奖与结算奖励拆分显示**）/商店/全通关，全部经 `flight_core.gd` 公开 API，经济未动。
   - `DEMO08_SHOTS_DIR` 环境变量触发的自动演示+离线截图通道（相当于 Movie Maker 用途的单帧捕获）。
2. **场景真实输入测试**（新文件 `game/tests/test_demo08_3d_scene.gd`，19 断言，退出码非零机制）：
   - 真实鼠标点击选关→两点折纸→完成按钮→键盘 UP/DOWN 设角→Space 蓄力 0.7s 释放→飞行→过关 30.1m→结算面板→点进商店→真实点击购买（扣币一次）→跳过→L2 折纸，全链路 19/19 PASS。
   - **场景层零漂移**：纯核心同参重放，按 flight_time 网格对齐 205/205 帧、最大偏差 **0.0000 px**——3D 表现层对模拟零干扰（相机不改速度/配平/门判定，阶段 A 完成边界达标）。
   - 3D 表现位置逐帧等于坐标契约换算；相机全程后上方跟随；R 复位不改变飞行状态。
3. **视觉验证与修复**（离线渲染截图 8 张，`reviews/shots/demo08-3d/`）：
   - 修复白底白字 bug（settle/menu/shop/final 面板标题与正文未设深色——2D 旧版有色、3D 版初版遗漏）。
   - 修复折纸按钮与底部提示重叠；修正自动演示截图时机（飞行后段原落在结算之后）。
   - 复核：结算面板"金币 +3（门奖 0 + 结算 3）"拆分可读；商店价格升序、买不起项置灰；飞行视角地平线稳定、飞机+阴影可读。

## 关键发现（记入已知坑）

- **headless 模式下合成输入事件到不了 GUI**：`root.push_input()` 与 `Input.parse_input_event()` 在 `-s` 脚本 headless 运行中均无法驱动按钮/键盘（探针实测，直连信号可以）。真实输入测试必须**窗口模式**运行（同离线渲染惯例，见 probe 结论；探针脚本已删）。
- 场景测试采样时序：`physics_frame`/`process_frame` 信号都在该帧回调**之前**触发，`await process_frame + await physics_frame` 才能拿到"上一帧已完成的 step+视觉"一致快照；逐帧 1:1 假设在窗口模式会被掉帧打破，重放比较需按 flight_time 网格对齐。
- 旧 itch CDN 故障日志仍在 pipeline-lite.log 尾部（平台侧历史问题，与本项目无关）。

## 证据

- `game/tests/test_demo08_3d.gd`：55 PASS / 0 FAIL（headless，EXIT=0）
- `game/tests/test_demo08_3d_scene.gd`：19 PASS / 0 FAIL（窗口模式真实输入，EXIT=0）
- 截图 8 张：`reviews/shots/demo08-3d/demo08-3d-0{1..8}-*.png`（menu/fold/fold-done/launch/flight-mid/flight-late/settle/shop）
- 运行命令：窗口模式 `Godot_v4.7.2-stable_win64_console.exe --path game res://demo08_3d.tscn`（DEMO08_SHOTS_DIR 触发自动演示）；测试 `-s res://tests/test_demo08_3d*.gd`

## Miro / 反馈

- pipeline-lite 日志与 backlog 复核：无 demo-08 新想法、无新玩家反馈。

## 未做 / 待办（下轮）

- **L2 真实输入完整局**（高/低门三维穿越 + 门奖 + 逆风）跑通后，阶段 A 完成边界即全部达成（参数/轨迹/币数对照已由核心测试覆盖）。
- Esc 暂停/恢复、失败重试路径的真实输入覆盖。
- MCP Pro 本轮未用（编辑器连接未确认指向本 worktree；headless+窗口 CLI 已满足验证；接入留到需要编辑器内检查时）。
- 发布：仍无可发布增量门槛（等 L1+L2 完整局），demos.json 不变；ChatGPT 评审待 L2 通后一并送。

## 下轮计划（阶段 A 收口）

L2 真实输入完整局（抬头吃高门/俯冲吃低门/直通三策略各一掷）→ 阶段 A 验收矩阵逐项打勾 → 送 ChatGPT 评审 → 决定是否发布 demo-08-3d-v1 灰模构建 → 进入阶段 B（A/D 有限侧向转向）。
