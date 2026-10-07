# L13 · 分段计时 · 规则契约（机制关卡 r3d-3）

## 概述
新增第十三关：**分段检查点计时**——首个"时钟状态门"。三处检查点设累计时限
（发车起算），跨线时比赛用时超过该点时限 → 超时判负（settle "late"）。
与 L12 限速门（瞬时速度）互补：分段计时是**积分判据**——慢段可由快段补偿，
但整体节奏不能拖；新增 HUD 元素（下一检查点剩余时间倒计时）。

## 判定模型（lane_core）
- setup 预计算 `checkpoints_px = {gx·10, tmax}`；step 记录 `prev_x`。
- 前向跨线（prev_x < gx ≤ car_pos.x，与限速线同机制）：
  - `flight_time > tmax` → settle "late"（记录 last_late = {gx, tmax, t}）；
  - 否则记入 `checkpoint_splits`（结算与测试用）。
- 刚体路径同规则：根脚本 `_physics_process_rigid` 以 `_rigid_prev_z` 跨线、
  `_rigid_time` 对比 tmax。
- HUD：`next_checkpoint()`（lane_core，桥梁）与 `_next_checkpoint_dict()`（根脚本，
  刚体）驱动 hint 行"检查点剩 x.x 秒（时限 y.y）"。
- `checkpoints` 字段门控：无该字段的关卡行为与旧版位级一致（lane 锁步锁定）。

## 关卡参数
| 参数 | 值 | 说明 |
|---|---|---|
| target_m | 600 | |
| min_wheels / rear_min | 2 / 2 | |
| budget | 0（不限） | |
| a1/w1 | 10 / 350 | 起伏丘（最大坡度 ~16°）：节奏扰动源 |
| a2/w2, a3/w3 | 5/140, 4/900 | |
| checkpoints | (220,5.4) (420,10.6) (560,14.0) | 累计时限 |

- 地形 seed：`900 + 12×77 = 1824`
- **时限标定**：全油门实测分段 4.6 / 9.0 / 12.0s（两种布局几乎一致——速度与轮径
  基本无关），tmax 取全油门 +15~20% 余量（0.8 / 1.6 / 2.0s）：刹停一次（约 +1.4s）
  即错过线 1，全程不敢怠速。
- 视觉：与限速线同族（gate_frame + pressure_plate 路面检测板，基座套件）；
  build_line_markers 泛化共用。

## 判定语义细节
- lane_core 油门为**二值**（旧 2D 语义：thr 只取符号，mag 恒为 DRIVE_ACC）——
  不存在部分油门；"犹豫"的代价只能是刹停/滑行损失（本关验收即用刹停注入）。
- 测试刹车窗必须以"仍有速度"为条件——刹停后若按位置出窗，车会在窗内被持续
  倒车振荡（guard 超时无结算）。

## 验收标准（l13viable 7/0）
1. 4×r14 对全油门三点全过完赛（13.2s，splits 4.6/9.0/12.0 三条记录）
2. 3×r16 三角全油门三点全过完赛（13.1s）
3. 140–170m 刹停重起步 → 线 1 超时判负（6.0 > 5.4）
4. next_checkpoint 语义：发车后指向第一检查点、完赛后为空
5. ≥2 布局限时完赛 + 超时判负可发生

## 实现
- garage_model：LEVELS 第十三条（checkpoints 字段）
- lane_core：checkpoints_px / checkpoint_splits / last_late + 跨线计时判定 + next_checkpoint()
- road_builder：build(…, checkpoints_m=[]) → build_line_markers 泛化（限速线/检查点共用）
- demo09_3d.gd：传 checkpoints；"分段计时超时"文案双路径；HUD 检查点倒计时（_checkpoint_hint）
