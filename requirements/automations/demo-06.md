# demo-06 词条涂鸦创造 · 专用自动化对话创建包

> 用法：**开一个新的 ZCode 聊天**，把本文件「——」以下的全部内容原样粘贴发送即可。该聊天将成为 demo-06 的专属开发对话，并创建自己的定时任务（每 30 分钟一轮，每小时 :25/:55 触发）。

---

创建一个定时任务（cron 表达式：`25,55 * * * *`），任务名：**每30分钟：demo-06 词条涂鸦创造 开发迭代评审发布**。

你是 TapTap2026 项目 demo-06「词条涂鸦创造」的专属自动化开发对话。仓库 D:\GIT\taptap2026（Bash 可用，PowerShell 用 powershell -File 调）。每 30 分钟一轮，按以下流程执行。

## 规格
requirements/backlog.md 的 demo-06 节 + Miro 原始想法。玩法：形状(圆球/长板/方块)×词条(Heavy/Float/Fire/Sticky)统一规则物理解谜，关卡只给目标不规定答案，墨水限制。目标 3-4 关。

## 当前状态
- public/demos.json 的 demo-06 slot（buildId=demo-06，L1 栅栏 + L2 高台已上线）
- headless 测试 game/tests/test_demo06_l3.gd（L3 断层关代码已写但物理卡死未解决——见下方已知坑）
- ChatGPT 专属监督对话（v2 迭代在此续评）：https://chatgpt.com/c/6ac0ce03-38a8-83ec-b06a-2a658c0a4753（结论 ITERATE）

## 每轮流程
1. 环境：curl -s http://localhost:8787/api/health；没响应就后台 node D:/GIT/taptap2026/server/server.js。（注意：测试验证不要用本地前端——直接用 GitHub Pages 公网链接 https://tonyguan530.github.io/taptap2026/play.html?id=<slotId> 或 itch 页面，截图/录屏也从公网页面取）
2. Miro 同步：node tools/miro-fetch.mjs；提取与词条涂鸦相关的新想法，更新 requirements/backlog.md 的 demo-06 节。
3. 反馈：data/db.json 的 demo-06 评论 + reviews/chatgpt-demo-06-full.md 结论（ITERATE：组合深度待验证——设计一个"没明显属性对应"的问题），挑可执行项落实。
4. 开发/迭代：改 game/demo06_inkwords.gd——先修复 L3 断层关的物理卡死（见已知坑），再按 ITERATE 建议扩展；headless 验证 game/tests/test_demo06_l3.gd。
5. 发布：切 project.godot main_scene → --import 校验 → powershell -File tools/export-web.ps1 -Version demo-06-vN → node tools/publish-qa.mjs <version>（FAIL=CDN 传播中，等 2-3 分钟重试；持续 FAIL=itch 平台故障，跳过 itch 改发 GitHub Pages 并记录）→ powershell -File tools/push-itch.ps1 -Version <version>。
6. Miro 上板：截图 reviews/shots/ + 录屏 reviews/videos/ + node tools/miro-post-shots.mjs（SHOTS 表更新 demo-06 行）。
7. 评审：ChatGPT 专属对话发版本说明+截图，抓回复存 reviews/chatgpt-demo-06-full.md 并更新映射。
8. 收尾：demos.json 更新、git push origin main、reports/ 报告、中文简短汇报。绝不把 data/secrets.json 内容写进报告或提交。

## 本 demo 已知坑（务必遵守）
- 【变量名】玩家变量是 player（CharacterBody2D），不是 ball；胜利判定是 state == "win"，没有 goal_reached——写测试前先读 demo06_inkwords.gd 确认。
- 【L3 断层关物理卡死（未解决）】物体掉进坑（y>500）后引擎物理步停摆（process 帧仍跑）——已试坠落复位/降台高度均未根治，修复前 L3 不可上线。排查线索：坑底 Rect2(340,520,420,40) + 左右台相邻布局，卡死发生在物体入坑落底时。
- 【 Godot 严格模式】clamp 返回 Variant 需显式 : float。
