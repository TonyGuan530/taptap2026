# demo-02 收束修复·单次执行指令（粘贴到 demo-02 对话框即可）

你是 demo-02 的执行会话。定时任务已取消——本次为**单次收束修复执行**，一口气完成下列三项，全程自主决策不提问。开工先读任务单全文：reviews/supervisor-directive-2026-10-07-demo02-closing-fix.md

## 执行清单（按序）

**FIX-1（3D·第三人称改版）**：codex/demo02-3d 分支（worktree D:\GIT\taptap2026-3d）。Camera3D 改 SpringArm3D 第三人称跟随球体（仓库先例 demo-06 3D SpringArm），保留按键切换第一人称。改完 headless 全套件回归 PASS → 发布 demo-02-3d-v15 → hub 槽切 v15（用户要玩到第三人称版；PINNED v10 基线目录保留不删）→ 重录五关视频。

**FIX-2（3D·L1 通关修复）**：用户亲测 L1 无法通关（自动化 9.3s 可过=人类窗口过苛）。弹簧触发窗口放宽（提前 0.2-0.3s）+ 弹射方向指示（箭头或轨迹虚线）。验收=普通玩家 3 次内通关（由用户复测确认）。与 FIX-1 同版发布。

**FIX-3（2D·L3 卡关缓解）**：main 分支 game/demo02_*.gd。用户卡 L3 组合关（羽毛跨峡谷三状态切换）。峡谷距离微缩 10-15% 或中段加借力平台（保持组合教学核心）→ headless 全套件回归 PASS → 发布 demo-02-v8 → hub 槽切 v8 → 视频重录。

## 每项收尾（不可省）

1. headless 回归 PASS（发布门槛）
2. Movie Maker 离线渲染视频（禁止开窗）
3. builds/demo-02-3d-v15（或 v8）+ demos.json 槽位切换 + build.json
4. git push（只 add 本任务文件）
5. GPT 视频验收：mp4 或 ffmpeg 抽 6-10 帧上传本专属对话，按两条标准请求裁决——①是否支撑 gamejam 涌现主题②完成度是否够玩家理解机制——PASS/FAIL+修改清单
6. GPT 判 FAIL → 按意见修改 → 复验循环直至 PASS

## 红线

- 禁止打开 Godot 编辑器/GUI（督导会杀进程）
- 禁止动 data/secrets.json
- v10 基线目录（PINNED）不删；2D v7 冻结基线不动玩法参数（FIX-3 只动 L3 几何距离）
- 单次执行不做 L6+ 新内容、不问问题、完成即汇报

## 完成回执

三项全部完成+GPT 验收 PASS 后，在对话里输出总结：各 FIX 的版本号、Pages 链接、GPT 裁决摘要。督导将归档并请用户复测。
