# 流水线报告 · demo-06 3D 阶段 A 收官（三解法真跑 3/3 + 12 组合对照）

- 时间：2026-10-05 02:45（22:25/21:55 跨场次轮）
- worktree：D:\GIT\taptap2026-demo06-3d（分支 codex/demo06-3d-migration）
- 约束遵守：全程 headless CLI / Movie Maker 离线渲染，未开 Godot 编辑器前端（用户指令）；L3 语义不动（开放断层，关卡只判 GOAL，不判解法）

## 本轮交付（阶段 A 待办三项全部闭合）

1. **L3 三解法真实物理驱动验证 3/3 PASS**（新测试 `game/tests/test_demo06_3d_l3_routes.gd`，每路独立场景实例+真实物理推进至 GOAL，退出码判定）：
   - A「Float 桥」：plank+float 40 墨，两段跳跨 2.7m 断层；
   - B「Sticky 垫脚」：block+sticky 40 墨，0.4s 物理钟延迟冻结成踏石；
   - C「推箱+垫块」（指南 §9「推箱 0~40 墨」）：推环境箱入坑抵右墙（自对齐 x≈5.08）→ 补 sticky 垫块落坑底（40 墨）→ 台缘走落垫块 → 垫块跳箱顶 → 箱顶回半步起跳上右台。坑深 1.7m vs 跳高 0.845m，坑底→箱顶 1.095m 不可直跳，垫块是几何必要补差。
2. **12 组合行为对照 PASS**（新测试 `test_demo06_3d_combos.gd`）：4 词条×3 形状全放置+逐组合原子扣费断言；Heavy mass8/×2.6、Float 即冻结、Fire 2s 物理钟自毁 3/3、Sticky 摩擦4 弹0 且 0.4s 前未冻结/后冻结 3/3；ball=SphereShape、plank/block=BoxShape。
3. **游戏本体 4 项实质改动**（`demo06_3d/demo06_root_3d.gd`）：
   - 词条计时改物理时钟（clock 累加 delta 替代 Time.get_ticks_msec）——离线渲染/测试确定性前提；
   - 玩家推箱冲量（move_and_slide 滑碰动态刚体施 25N·delta 冲量）——解法 C 通道；
   - 环境箱改动态 RigidBody（低摩擦 0.4，独立 props_root 与词条放置物分账）——可推/可撞；
   - 放置物词条计时随物理钟（Fire die_at / Sticky freeze_at）。

## 调试中定位并修复的驱动层根因（游戏本体无此问题）

- **空中方向清零=原地直上直下跳**：旧影片驱动 `py>2.0/!on_floor → auto_dir=ZERO`，而游戏 `velocity.x=dir.x` 每 tick 重写——跳跃无水平抛物线，玩家在跳窗内无限原地弹跳后落入坑中贴墙（上一轮影片实为失败走法）。修复：驱动恒定行进方向（模拟按住 D 不放，与 2D L3 驱动一致）。
- 板上站立中心 y≈2.07 使 `py<1.9` 第二跳窗永不触发；改为按台面/板面分 py 区间窗。
- 跨路场景泄漏：三路测试共用进程，旧实例未释放导致 B 路玩家站在 A 路残留 Float 板上——每路结束 free。
- C 路「相位内空中方向翻转」弹跳：回退/跳跃拆分相位，起跳后方向恒定。

## 测试与发布

- 全量回归：`test_demo06_3d_smoke` PASS（exit 0）+ `test_demo06_3d_combos` PASS（exit 0）+ `test_demo06_3d_l3_routes` 3/3 PASS（exit 0）。
- 影片：修复后走法 Movie Maker 离线渲染 540 帧（WALKTHROUGH_WIN t=176 + GOAL_REACHED）→ ffmpeg → 主仓库 `reviews/videos/demo-06-3d.mp4`（9s）+ 抽帧 `reviews/shots/demo-06-3d.png`。
- 已知停摆一次（headless 随机 7MB 僵尸，重试自愈，符合预案）。

## 待办（下轮）

- demo-06-3d-v1 Web 构建：worktree 导出 → 主仓库 builds/ → demos.json demo-06-3d slot → push 触发 Pages → curl 验证（「做完即传」补课）。
- ChatGPT 评审（专属对话）：三解法 3/3 真跑证据 + 12 组合对照表 + 影片。
- 阶段 A 验收复核后进阶段 B（L1-L6 六关 3D 迁移，保留 L3 主 Gate）。
