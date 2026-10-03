# demo-02 物性变换谜题 · 专用自动化对话创建包

> 用法：**开一个新的 ZCode 聊天**，把本文件「——」以下的全部内容原样粘贴发送即可。该聊天将成为 demo-02 的专属开发对话，并创建自己的定时任务（每 30 分钟一轮，每小时 :05/:35 触发）。

✅ **已创建**（2026-10-03）：automation id `automation-8af780c6-0f5b-482a-b6a1-a375506f1683`，cron `5,35 * * * *`，本聊天即 demo-02 专属对话。

---

创建一个定时任务（cron 表达式：`5,35 * * * *`），任务名：**每30分钟：demo-02 物性变换谜题 开发迭代评审发布**。

你是 TapTap2026 项目 demo-02「物性变换谜题」的专属自动化开发对话。仓库 D:\GIT\taptap2026（Bash 可用，PowerShell 用 powershell -File 调）。每 30 分钟一轮，按以下流程执行。

## 规格
requirements/backlog.md 的 demo-02 节 + Miro 原始想法（requirements/miro-export.md）。玩法：形状(圆球/长板/方块)×词条(Heavy/Float/Fire/Sticky)统一规则物理解谜，目标 3-4 关。

## 当前状态
- public/demos.json 的 demo-02 slot（buildId=demo-02-v3，3 关已上线；v3=跳跃输入+组合测试房，headless 4/4 PASS）
- ChatGPT 复评 v3 结论 **KEEP**（首次进入候选核心机制池）；完整结论存 reviews/chatgpt-demo-02-full.md 尾部
- itch：demo-02-v3 已推（butler build #2057309）但 CDN 持续故障（占位页 404，publish-qa FAIL）→ 可玩链接走 GitHub Pages；pipeline-lite 每 5 分钟自愈重推
- 待办 v4（按 KEEP 后指令）：①删 Space 通用跳，扑翼削为一次性轻 impulse，保留横移 ②开放 L4（只查 GOAL 不查词条序列，≥2 条合法路线）③公开 build 隐藏「参考解法」+ 3-5 人无提示试玩
- v4 禁止：堆词条 / 加角色能力 / 传统 platformer 操作
- 停滞兜底（用户指令）：轮次无可执行项或连续两轮无实质变化时，按序挑一项做——①扩展玩法（评审约束内）②补充关卡 ③迭代美术 ④转 3D 尝试（仅当 2D 到天花板且玩法合适，先征求 ChatGPT 评审意见）；所选方向写进报告与汇报
- 已知坑新增：【羽毛 damp=1.2 会吃掉弹簧冲量】L3 弹簧冲量 (260,-660) 是抵消阻尼后的调参值，改词条参数需同步重调 L3 并跑 headless

## 每轮流程
1. 环境：curl -s http://localhost:8787/api/health；没响应就后台 node D:/GIT/taptap2026/server/server.js。（注意：测试验证不要用本地前端——直接用 GitHub Pages 公网链接 https://tonyguan530.github.io/taptap2026/play.html?id=<slotId> 或 itch 页面，截图/录屏也从公网页面取）
2. Miro 同步：node tools/miro-fetch.mjs；提取与物性变换相关的新想法，更新 requirements/backlog.md 的 demo-02 节。
3. 反馈：data/db.json 的 demo-02 评论 + reviews/chatgpt-demo-02-full.md 结论，挑可执行项落实。
4. 开发/迭代：改 game/demo02_physics.gd（当前 2 关 → 3-4 关）；headless 测试 game/tests/test_demo02_v2.gd 风格。
5. 发布：切 project.godot main_scene → --import 校验 → powershell -File tools/export-web.ps1 -Version demo-02-vN → node tools/publish-qa.mjs <version>（FAIL=CDN 传播中，等 2-3 分钟重试；持续 FAIL=itch 平台故障，跳过 itch 改发 GitHub Pages 并记录）→ powershell -File tools/push-itch.ps1 -Version <version>。
6. Miro 上板：截图 reviews/shots/ + 录屏 reviews/videos/ + node tools/miro-post-shots.mjs。
7. 评审：ChatGPT 专属对话（上方 URL）发版本说明+截图，抓回复存 reviews/chatgpt-demo-02-full.md。
8. 收尾：demos.json 更新、git push origin main、reports/ 报告、中文简短汇报。绝不把 data/secrets.json 内容写进报告或提交。

## 本 demo 已知坑（务必遵守）
- 【禁止本地前端测试】（用户指令 2026-10-03）本地站（localhost:8787）只做 Review 留言板；测试验证一律 godot --headless（逻辑）+ 公网 Pages/itch（真机与发布完整性，curl build.json=200 / publish-qa）。截图/录屏也从公网页面取。
- 【没有 keys/state 变量】球是纯物理自动滚动，无输入系统。测试时只允许使用实际存在的变量：goal_reached / ball / prev_speed / tag_idx / _on_tag / _load_level。写测试前先读 game/demo02_physics.gd 确认。
- 【测试用文件日志】headless 测试的 print 在超时杀进程时会全丢——用 FileAccess 写 user://v2log.txt 并 flush（参考 game/tests/test_demo02_v2.gd）。
- 【Float 词 g=0.05 缓降，不是 0】；脆墙判定是纯物理（撞击速度 ≥450）。
- 【itch 平台故障期】若 publish-qa 持续 FAIL（CDN 404 占位页），跳过 itch 推送改用 GitHub Pages（自动 CI），并在报告注明。


## 停滞即转向（扩展阶梯）

本 demo 连续 2 轮没有实质进展时，按阶梯转向，选第一合适的：
1. 扩展玩法：给现有机制加新组合
2. 补充关卡：用现有机制加 1-2 个关卡
3. 迭代美术：视觉/音效/反馈打磨
4. 转 3D 尝试：仅玩法确实适合 3D 时，先说明可行性再动手

转向时在报告注明「停滞转向：demo-0X → 阶梯项」。
