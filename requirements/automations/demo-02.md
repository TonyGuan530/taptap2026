# demo-02 物性变换谜题 · 专用自动化对话创建包

> 用法：**开一个新的 ZCode 聊天**，把本文件「——」以下的全部内容原样粘贴发送即可。该聊天将成为 demo-02 的专属开发对话，并创建自己的定时任务（每 30 分钟一轮，每小时 :05/:35 触发）。

---

创建一个定时任务（cron 表达式：`5,35 * * * *`），任务名：**每30分钟：demo-02 物性变换谜题 开发迭代评审发布**。

你是 TapTap2026 项目 demo-02「物性变换谜题」的专属自动化开发对话。仓库 D:\GIT\taptap2026（Bash 可用，PowerShell 用 powershell -File 调）。每 30 分钟一轮，按以下流程执行。

## 规格
requirements/backlog.md 的 demo-02 节 + Miro 原始想法（requirements/miro-export.md）。玩法：形状(圆球/长板/方块)×词条(Heavy/Float/Fire/Sticky)统一规则物理解谜，目标 3-4 关。

## 当前状态
- public/demos.json 的 demo-02 slot（buildId=demo-02-v2，L1+L2 已上线）
- ChatGPT 专属监督对话（迭代时在此续评）：https://chatgpt.com/c/6abf238d-6dc0-83ec-aa5e-43c62aebe892（结论 ITERATE）
- 待办 v3：加跳跃输入系统，实现评审建议#2「组合测试房」（空中切词条：弹簧→Float→石头砸舱门）

## 每轮流程
1. 环境：curl -s http://localhost:8787/api/health；没响应就后台 node D:/GIT/taptap2026/server/server.js。
2. Miro 同步：node tools/miro-fetch.mjs；提取与物性变换相关的新想法，更新 requirements/backlog.md 的 demo-02 节。
3. 反馈：data/db.json 的 demo-02 评论 + reviews/chatgpt-demo-02-full.md 结论，挑可执行项落实。
4. 开发/迭代：改 game/demo02_physics.gd（当前 2 关 → 3-4 关）；headless 测试 game/tests/test_demo02_v2.gd 风格。
5. 发布：切 project.godot main_scene → --import 校验 → powershell -File tools/export-web.ps1 -Version demo-02-vN → node tools/publish-qa.mjs <version>（FAIL=CDN 传播中，等 2-3 分钟重试；持续 FAIL=itch 平台故障，跳过 itch 改发 GitHub Pages 并记录）→ powershell -File tools/push-itch.ps1 -Version <version>。
6. Miro 上板：截图 reviews/shots/ + 录屏 reviews/videos/ + node tools/miro-post-shots.mjs。
7. 评审：ChatGPT 专属对话（上方 URL）发版本说明+截图，抓回复存 reviews/chatgpt-demo-02-full.md。
8. 收尾：demos.json 更新、git push origin main、reports/ 报告、中文简短汇报。绝不把 data/secrets.json 内容写进报告或提交。

## 本 demo 已知坑（务必遵守）
- 【没有 keys/state 变量】球是纯物理自动滚动，无输入系统。测试时只允许使用实际存在的变量：goal_reached / ball / prev_speed / tag_idx / _on_tag / _load_level。写测试前先读 game/demo02_physics.gd 确认。
- 【测试用文件日志】headless 测试的 print 在超时杀进程时会全丢——用 FileAccess 写 user://v2log.txt 并 flush（参考 game/tests/test_demo02_v2.gd）。
- 【Float 词 g=0.05 缓降，不是 0】；脆墙判定是纯物理（撞击速度 ≥450）。
- 【itch 平台故障期】若 publish-qa 持续 FAIL（CDN 404 占位页），跳过 itch 推送改用 GitHub Pages（自动 CI），并在报告注明。
