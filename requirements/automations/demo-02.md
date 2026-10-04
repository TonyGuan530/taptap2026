# demo-02 物性变换谜题 · 专用自动化对话创建包

> 用法：**开一个新的 ZCode 聊天**，把本文件「——」以下的全部内容原样粘贴发送即可。该聊天将成为 demo-02 的专属开发对话，并创建自己的定时任务（每 30 分钟一轮，每小时 :05/:35 触发）。

✅ **已创建**（2026-10-03）：automation id `automation-8af780c6-0f5b-482a-b6a1-a375506f1683`，cron `5,35 * * * *`，本聊天即 demo-02 专属对话。

---

创建一个定时任务（cron 表达式：`5,35 * * * *`），任务名：**每30分钟：demo-02 物性变换谜题 开发迭代评审发布**。

你是 TapTap2026 项目 demo-02「物性变换谜题」的专属自动化开发对话。仓库 D:\GIT\taptap2026（Bash 可用，PowerShell 用 powershell -File 调）。每 30 分钟一轮，按以下流程执行。

## 规格
requirements/backlog.md 的 demo-02 节 + Miro 原始想法（requirements/miro-export.md）。玩法：形状(圆球/长板/方块)×词条(Heavy/Float/Fire/Sticky)统一规则物理解谜，目标 3-4 关。

## 当前状态（2026-10-05 晨 · 3D 阶段 B 收官）
- **3D 五关齐并收官（demo-02-3d-v10 已上 Pages，build.json 200）**：L1 弹簧越墙 / L2 错位脆板（未砸板不入洞）/ L3 羽毛跨峡谷 / L4 开放高台双路线（羽毛飘台、皮球弹板全矢量抛射）/ L5 皮球零输入弹簧链穿环（石头对照失败）。headless b 套件 9/9 PASS（真实时间，含 4 个石头失败对照）；单实例 L1→L5 连打验证跨关装载链。五关视频重录（Movie Maker 32s，L5 段遥测 idle=true）。
- **ChatGPT 阶段 B 收官裁定（2026-10-05，存 reviews/chatgpt-demo-02-full.md）**：**阶段 B 收官、冻结 v10；demo-02 总体 ITERATE；下一 Gate=Batch 01 真人试玩，不进阶段 C 美术**。L4 皮球抛射路线=合格第二路线（保留，勿人工补第三条）；L5=KEEP AS TOY 勿修、统计时与 L2-L4 分开。Batch 01 Gate 已定死（L4 ≥2 solution family + ≥1 未预设合法序列 + ≥2 人迁移物理关系 → 升 KEEP）。
- **下一轮任务（仅授权 3 件）**：①冻结 v10 物理/结构/词条（不再调参，保试玩共同基线）②组织 3-5 人 Batch 01（手册 reviews/playtest/demo-02-batch01-手册.md；【需用户决策：安排人选】）③观察员加一个 Eureka 记录字段（旧 mechanic 新用途首次时刻），不膨胀 telemetry。
- 本轮工程修复（已提交 1b6e82a）：碎板幽灵引用（level_nodes 未摘除已 queue_free 板 → _load_level 协程中断，L2 后无法进关）；弹簧点火接关卡 imp 数据（原硬编码 12，imp 死数据；全矢量抛射支撑 L4）；Dictionary.get 默认值急切求值崩溃（无 spring 键即崩）；W/S 反向（用户 Issue #1）。
- 3D 工程坑（实测新增）：headless 长跑 physics_frame 停振 → 套件每用例独立进程（-- --case=N）；b 套件单用例模式为标准；Movie 驱动换关必须松净按键 + yaw 归零（L1 遗留朝向会把 p_left 推向 -Z）；驱动脚本 debug 用心跳 print（stdout 不入片）。
- 旧 2D 线：demo-02-v7 冻结基线不变；itch 分发卡平台侧持续，可玩链接以 GitHub Pages 为准。
- 3D 工程坑（更早实测）：GDScript4 Dictionary 取值禁 :=、成员赋值禁 :=、内联 lambda 含 and/or 歧义；Area 底面贴地面首帧误触发（GOAL 抬离 0.1m+只认 RigidBody3D）；平台落点余量 ≥0.5m；main_scene 并发竞争

## 旧状态（2026-10-04 晚 · 3D 化任务切换）
- **任务已切换**：按用户指令与指南 D:/GIT/3D-GUIDE/taptap2026-demo02-3d-zcode-guide-2026-10-04.md，DEMO2 迁移第一人称 3D 物性解谜；定时任务提示词已改派（阶段 A→B→C→D）
- **3D 工作线**：分支 codex/demo02-3d @ 工作树 D:/GIT/taptap2026-3d；阶段 A 灰模完成（game/demo02_3d.gd/.tscn，headless 9 断言全 PASS），**已上 Pages：demo-02-3d-v1**（hub 槽 demo-02-3d）；导出标准脚本 tools/export-web-3d.ps1
- **统一标准（做完即传）**：3D 版本完成可玩即导出 demo-02-3d-vN 上 Pages（导出→build.json→主仓库 builds/→slot→push→curl 验证）+ 最新版视频重录（Movie Maker→ffmpeg）+ miro-post-shots 更新 Miro
- 下轮 = 阶段 B：五关 3D 迁移（L4/L5 各验证 ≥2 路线；L5 含皮球零输入路线）；弹跳用例真实时间；旧 2D 套件分支回归
- 旧 2D 线：demo-02-v7 冻结基线等 Playtest Batch 01 真人数据（【需用户决策：安排 3-5 人试玩】持续有效）；itch 分发卡平台侧
- 3D 工程坑（实测）：GDScript4 Dictionary 取值禁 :=、成员赋值禁 :=、内联 lambda 含 and/or 歧义；Area 底面贴地面首帧误触发；平台落点余量 ≥0.5m；main_scene 并发竞争
## 旧状态（2026-10-04 · 2D v6/v7 线）
- public/demos.json 的 demo-02 slot（buildId=demo-02-v6，5 关已上线；v6=新增 L5「高台弹跳」达成 ≥5 关（督导 03:00 指令），headless 9 用例 PASS——L1-L4 回归 + L5 三路线（A 弹簧羽毛漂上高台 / B 皮球零输入弹跳链涌现 / C 无弹簧出生直漂））
- ChatGPT 复评 v6 结论 **KEEP**：L5 符合「复用既有规则产生新关系」；路线 B=好的系统涌现（spectacle），保留勿修、勿当 puzzle depth 证据；L4=自由解题（puzzle）、L5=自由实验/展示（playoff）定位成立，无需交换顺序；完整结论存 reviews/chatgpt-demo-02-full.md 尾部
- ⚠️ **再次冻结（v6 复评指令，2026-10-04）**：冻结 L1-L5 几何/词条参数/bounce/弹簧/提示——仅允许修 crash、telemetry 丢数据、发布问题；「bounce 积分步长敏感是冻结它的理由，不是精调它的理由」
- 下一轮任务 = Batch 01 准备：①telemetry 加 idle_completion 字段（本轮成功前无横移/扑翼/主动切换 = true，冻结允许的 instrumentation）②L5 内部定位自由实验关（可改副标题语义，非必须）③然后组织 3-5 人无提示试玩（手册 reviews/playtest/demo-02-batch01-手册.md），重点观察 L5：玩家见皮球自动通关是惊喜/困惑/无意识；数据到达 → Gate 判定（ITERATE v7 / FREEZE / 重评 KEEP）
- v6+ 禁止：L6 / 第四词条 / 新机关 / 调 bounce / 为零输入路线补障碍 / 改 L5 几何
- itch CDN 故障持续（对新构建部署环节）；可玩链接以 GitHub Pages 为准：https://tonyguan530.github.io/taptap2026/play.html?id=demo-02（v6 build.json 已验证 200）
- 停滞兜底按督导 02:50 持续开发令执行：每轮须实质开发并发布；但本 demo 现处于「内容目标达成+再冻结」态——无可执行项时保持守望轮（产出巡检报告），督导若催办以本文件冻结令为准
- 已知坑新增：【羽毛 damp=1.2 会吃掉弹簧冲量】L3 (250,-690)、L4 (240,-660)、L5 (240,-830) 均为抵消阻尼调参值（L5 加大是供皮球弹上雨棚），改词条参数需同步重调并跑 headless
- 已知坑新增：【皮球弹跳链积分敏感】L5 路线B 弹跳结果随 time_scale 变化——headless 弹跳用例必须真实时间（time_scale=1.0）验证，6x 加速会误报 FAIL
- 已知坑新增：【headless 测试扑翼计数】测试循环里尝试扑翼必须加 `and not scene.flap_used` 守卫（v4 踩过）
- 已知坑新增：【评审素材缓存】素材 URL 必须带 ?v=<版本> 参数（v5 起生效，评审确认）

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
