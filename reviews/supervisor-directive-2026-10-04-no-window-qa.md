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


---

## 加严（21:05·用户二次强调「不要打开godot前端开发抢我鼠标」）

用户被再次打断——升级为**硬红线**：

1. **Godot 编辑器 GUI 一律禁止打开**：包括「打开工程看一眼效果」「编辑器里预览场景」「项目管理器」——任何时候、任何理由都不行。
2. **仅允许的形态**：命令行 `--headless` 开头的一切用法（import / --check-only / -s 测试脚本 / --write-movie 离线渲染）。
3. **督导巡检授权（用户授权的零打扰执行）**：督导每轮巡查用 Get-CimInstance 检查全部 Godot 进程命令行，**凡命令行不含 --headless 的进程立即 taskkill 杀掉**，不预告不等待，事后在批示本文件登记 [KILLED HH:MM PID 任务]。
4. 任务侧自检：跑任何 Godot 命令前自查命令行必须含 --headless；场景视觉效果一律用 --write-movie 渲染出图后查看图片文件。


[KILLED 02:50 督导巡检] PID 40376/37752（Godot 无 --headless，违规开窗）已 taskkill——硬红线执行。

[Miro Feedback 协议·用户设立 2026-10-05] Feedback Slide 区（Miro 负坐标区）为用户专用反馈区：各任务每轮优先阅读；完成后用 tools/miro-post-feedback-note.mjs 自己在 Miro 标注 + 更新 public/feedback-board.json。否决裁决归档：「本地AI小模型限于浏览器性能不可行」（不得再提）。FB-001/002/003 全部已由 AL 修复标注，督导侧 json 状态已同步 fixed。
