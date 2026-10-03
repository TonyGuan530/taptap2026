# demo-02 物性变换谜题 · 专用自动化对话创建包

> 用法：**开一个新的 ZCode 聊天**，把本文件「——」以下的全部内容原样粘贴发送即可。该聊天将成为 demo-02 的专属开发对话，并创建自己的定时任务（每 30 分钟一轮，每小时 :05/:35 触发）。

✅ **已创建**（2026-10-03）：automation id `automation-8af780c6-0f5b-482a-b6a1-a375506f1683`，cron `5,35 * * * *`，本聊天即 demo-02 专属对话。

---

创建一个定时任务（cron 表达式：`5,35 * * * *`），任务名：**每30分钟：demo-02 物性变换谜题 开发迭代评审发布**。

你是 TapTap2026 项目 demo-02「物性变换谜题」的专属自动化开发对话。仓库 D:\GIT\taptap2026（Bash 可用，PowerShell 用 powershell -File 调）。每 30 分钟一轮，按以下流程执行。

## 规格
requirements/backlog.md 的 demo-02 节 + Miro 原始想法（requirements/miro-export.md）。玩法：形状(圆球/长板/方块)×词条(Heavy/Float/Fire/Sticky)统一规则物理解谜，目标 3-4 关。

## 当前状态
- public/demos.json 的 demo-02 slot（buildId=demo-02-v4，4 关已上线；v4=删通用跳+扑翼单次修正+开放 L4，headless 6/6 PASS）
- ChatGPT 复评 v4 结论 **KEEP**（Systemic Puzzle Gate 通过：v1 Scripted→v4 Systemic solution space）；完整结论存 reviews/chatgpt-demo-02-full.md 尾部
- itch CDN 故障持续（占位页）；可玩链接以 GitHub Pages 为准：https://tonyguan530.github.io/taptap2026/play.html?id=demo-02（v4 build.json 已验证 200）
- 待办 v5（按 v4 KEEP 后指令）：①不新增 L5，做 3-5 人无提示真人试玩 + 轻量 telemetry（切换时间/重置次数/关键区域/最终路线）②物性变化最小即时反馈层（纯 UI/FX：轻/重/弹关键词、撞板速度反馈）③素材 URL 加版本参数防 raw CDN 缓存
- v5 禁止：L5 / 第四词条 / 新技能 / 新机关族 / 大地图 / 刻意堆解法
- 停滞兜底（用户指令）：轮次无可执行项或连续两轮无实质变化时，按序挑一项做——①扩展玩法（评审约束内）②补充关卡 ③迭代美术 ④转 3D 尝试（仅当 2D 到天花板且玩法合适，先征求 ChatGPT 评审意见）；所选方向写进报告与汇报。注意 v5 的信息瓶颈是真人数据，无可执行项时优先做反馈层/遥测类小活，不要扩张系统
- 已知坑新增：【羽毛 damp=1.2 会吃掉弹簧冲量】L3 冲量 (250,-690)、L4 冲量 (240,-660) 都是抵消阻尼的调参值，改词条参数需同步重调并跑 headless
- 已知坑新增：【L4 路线A 不需要弹簧】羽毛从出生直接横漂即可入舱（评审认可的涌现信号）；改地形前先跑 test_demo02_v4.gd 确认 A/B 双路线仍成立
- 已知坑新增：【headless 测试扑翼计数】测试循环里尝试扑翼必须加 `and not scene.flap_used` 守卫，否则每帧递增提前退出循环（v4 踩过）

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
