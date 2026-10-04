# 督导总指挥令 2026-10-04 21:00·禁止弹窗 QA（最高优先级·零打扰红线延伸）

> 用户原话：「他们不要做弹出游戏的QA 我电脑上要玩游戏 就CLI截图就好」。用户正在电脑上玩游戏，任何弹出 Godot 窗口的验证行为都会抢焦点打断游戏——**等同零打扰红线**。

## 规定（全体开发任务立即生效）

1. **禁止**：非 headless 方式运行游戏/场景做 QA 验证（含 godot 直接跑场景、开 Godot 编辑器交互操作、任何会弹出窗口的验证）。
2. **一律 CLI 离线验证**：
   - 视觉验证 = Movie Maker 离线渲染（godot --headless --write-movie out.avi --fixed-fps 30 <场景> → ffmpeg 转 mp4/抽帧）或 headless 截图脚本（Viewport 渲染→save png）。
   - 逻辑验证 = --headless 测试脚本 + --check-only 脚本编译 + --import 资源导入。
3. 既有 headless 流程（test_demo*.gd、dominance、--import、CI 导出）本就不开窗，继续照旧。
4. 3D 迁移期尤其注意：3D 场景验证不得开编辑器/窗口——用 headless 渲染截图看画面。
5. 违反本令 = 打断用户游戏，按零打扰红线处置（督导巡查发现即催办纠正）。

## 督导侧同步

- 督导同样遵守（不开任何窗口）；巡查时把「任务是否弹窗」纳入异常观测。
