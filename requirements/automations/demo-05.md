# demo-05 重生之我是恐龙·火山生存 · 专用自动化对话创建包

> 用法：**开一个新的 ZCode 聊天**，把本文件「——」以下的全部内容原样粘贴发送即可。该聊天将成为 demo-05 的专属开发对话，并创建自己的定时任务（每 30 分钟一轮，每小时 :20/:50 触发）。

---

创建一个定时任务（cron 表达式：`20,50 * * * *`），任务名：**每30分钟：demo-05 恐龙火山生存 开发迭代评审发布**。

你是 TapTap2026 项目 demo-05「重生之我是恐龙·火山生存」的专属自动化开发对话。仓库 D:\GIT\taptap2026（Bash 可用，PowerShell 用 powershell -File 调）。每 30 分钟一轮，按以下流程执行。

## 规格
requirements/backlog.md 的 demo-05 节 + Miro 原始想法（现代恐龙意识 + 火山灾害生存策略，含地形风险/资源分散储备/灾后动态灾害连锁）。玩法：准备期分散储备 → 火山爆发随机灾害链 → 撤离决策 → 末日故事结算。

## 当前状态
- public/demos.json 的 demo-05 slot（buildId=demo-05，60 秒生存局已上线）
- headless 平衡测试 game/tests/test_demo05.gd（分散储备富余存活 / 全押河谷遇雨储备尽失，双 PASS）
- ChatGPT 监督对话尚未建立（本聊天即为起点，创建后把对话 URL 记入 reviews/chatgpt-conversations.json）
- ITERATE 反馈（demo-05 监督评审）：验证「玩家连玩 5 局会出现 3-4 种都成立的策略」——需要策略多样性扩展（酸雨事件/建筑系统等 Miro 扩展贴纸）
- ✅ 定时任务已创建（2026-10-03，本对话，automation-684bb086）：cron `20,50 * * * *`，任务名「每30分钟：demo-05 恐龙火山生存 开发迭代评审发布」。本对话 URL：待填

## 每轮流程
1. 环境：curl -s http://localhost:8787/api/health；没响应就后台 node D:/GIT/taptap2026/server/server.js。（注意：测试验证不要用本地前端——直接用 GitHub Pages 公网链接 https://tonyguan530.github.io/taptap2026/play.html?id=<slotId> 或 itch 页面，截图/录屏也从公网页面取）
2. Miro 同步：node tools/miro-fetch.mjs；提取与恐龙火山相关的新想法，更新 requirements/backlog.md 的 demo-05 节。
3. 反馈：data/db.json 的 demo-05 评论，挑可执行项落实。
4. 开发/迭代：改 game/demo05_volcano.gd——扩展方向（与 GPT 讨论后定）：酸雨事件（Miro 扩展贴纸）、建筑系统（初始建筑：山）、群体系统、多轮难度；headless 平衡测试 game/tests/test_demo05.gd 风格（会玩→胜 / 摆烂→败 双用例，改参数后必须重跑）。
5. 发布：切 project.godot main_scene → --import 校验 → powershell -File tools/export-web.ps1 -Version demo-05-vN → node tools/publish-qa.mjs <version>（FAIL=CDN 传播中，等 2-3 分钟重试；持续 FAIL=itch 平台故障，跳过 itch 改发 GitHub Pages 并记录）→ powershell -File tools/push-itch.ps1 -Version <version>。
6. Miro 上板：截图 reviews/shots/ + 录屏 reviews/videos/ + node tools/miro-post-shots.mjs（SHOTS 表更新 demo-05 行）。
7. 评审：ChatGPT 专属对话发背景+截图+supervisor-prompt.md 链接，抓回复存 reviews/chatgpt-demo-05-full.md 并更新映射。
8. 收尾：demos.json 更新、git push origin main、reports/ 报告、中文简短汇报。绝不把 data/secrets.json 内容写进报告或提交。

## 本 demo 已知坑（务必遵守）
- 【平衡联动】改温度曲线/设施/村民参数后必须重跑 test_demo05.gd 双用例——会玩必须能胜、摆烂必须能败。
- 【 headless 测试用真实时间计时】（time_scale 加速），按帧数计时毫无意义。
- 【 Godot 严格模式】clamp 返回 Variant 需显式 : float；CanvasLayer 不能赋给 Control 变量。
