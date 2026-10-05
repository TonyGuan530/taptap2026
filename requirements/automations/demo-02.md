# demo-02 物性变换谜题 · 专用自动化对话创建包

> 用法：**开一个新的 ZCode 聊天**，把本文件「——」以下的全部内容原样粘贴发送即可。该聊天将成为 demo-02 的专属开发对话，并创建自己的定时任务（每 30 分钟一轮，每小时 :05/:35 触发）。

✅ **已创建**（2026-10-03）：automation id `automation-8af780c6-0f5b-482a-b6a1-a375506f1683`，cron `5,35 * * * *`，本聊天即 demo-02 专属对话。

---

创建一个定时任务（cron 表达式：`5,35 * * * *`），任务名：**每30分钟：demo-02 物性变换谜题 开发迭代评审发布**。

你是 TapTap2026 项目 demo-02「物性变换谜题」的专属自动化开发对话。仓库 D:\GIT\taptap2026（Bash 可用，PowerShell 用 powershell -File 调）。每 30 分钟一轮，按以下流程执行。

## 规格
requirements/backlog.md 的 demo-02 节 + Miro 原始想法（requirements/miro-export.md）。玩法：形状(圆球/长板/方块)×词条(Heavy/Float/Fire/Sticky)统一规则物理解谜，目标 3-4 关。

## 当前状态（2026-10-06 晨 · 守望巡检轮）
- **守望轮记录**：L8 弹簧调参后全套 15 案保险复验通过（④ 启动停振为 .godot 缓存损坏，清缓存即愈——批跑后建议主动清缓存防连带）。Pages 三基线 200，PINNED 完好，反馈板无新数据。探索线定稿 L8/v14，等待 Batch 01（用户安排人选）→ 核心 Gate → 探索关轻裁。加关边际价值已尽（L9 dead-end 见下），转纯守望。
- **L9（走道弹射+回落重试）设计并撤销**：实测球体落地即冻结（无地面驱动，W 无效）——「落地走回弹射器重试」的回路结构性不成立，玩家会硬死锁。已回退 L9 全部改动（LEVELS/用例），套件保持 15/15（HEAD 66b32c4 状态）。**设计空间结论入指南附录#4：所有路线必须纯空中链路。**探索线定稿于 L8（v14）；再加关前先等 Batch 01/监督裁定。
- **L8 robustness gate 完成（test_demo02_3d_r8.gd）**：砸桥冲击 12.5 对阈 11（+13%）跨 30/60/120Hz+扰动全稳（30Hz 桥漏接已由调参消除）；羽毛轻过全配置不碎桥且过关。L8 弹簧调参 (5.5,14)→(4.5,15.5)，(4,16.5) 高弧落点飘过桥尾被否——margin 上限受桥位约束，已记入并入检查单。v14 探索版直链 https://tonyguan530.github.io/taptap2026/builds/demo-02-3d-v14/index.html （hub 未切）。
- **L8 桥上桥下落地（demo-02-3d-v13 直链 https://tonyguan530.github.io/taptap2026/builds/demo-02-3d-v13/index.html ，hub 槽未切）**：同一脆板双语义——羽毛轻落桥面滚过桥尾（桥不碎）／皮球全弧砸断脆桥坠谷底；b 套件扩至 **15/15 全绿**；机制扩展=脆板 require_break 过关门可按关关闭（L2/L7 默认 true 不变）。探索内容不并入基线。
- 新增工程坑：④批跑 15 连发引擎后必现启动停振——批内清僵尸（两个镜像名 taskkill）+ 必要时删 .godot；yaw=-PI/2 时 p_left 刹车推的是 Z 轴不是 -X（L2/L8 两次踩中——横向刹车用「松 W 靠阻尼」替代）；测试节点替换用 node 正则跨行匹配会吞码——恢复用 git checkout HEAD + 精确 Edit 重打。
- **⚠️ v10 基线险情（当日）**：并行会话的「体积自动清理」把 builds/demo-02-3d-v10 当被取代版本删除（commit 0e45c79），hub 槽与试玩链接一度全坏——已从 git 历史恢复并重新上线（200）。**任何版本清扫不得删 builds/demo-02-3d-v10**（目录内已放 PINNED.md 标记）：它是 Batch 01 唯一基线，直到数据回收出 Gate。同理 2D 的 demo-02-v7 亦为冻结基线勿删。
- **L7 robustness gate 完成（test_demo02_3d_r7.gd）**：石头破窗冲击 16.8-17.0 对阈 14（+20%）在 60/120Hz+出生扰动全稳；皮球 ≤12.2 全配置不破（-13%）；30Hz 失败为测试架构伪影（Movie Maker 实测 30Hz 正常）。监督三原则已写入 3D 指南附录；L7 并入正篇前再过一次该 gate 即可。
- **L7 破窗密室落地（demo-02-3d-v12 直链 https://tonyguan530.github.io/taptap2026/builds/demo-02-3d-v12/index.html ，hub 槽未切）**：弹簧冲天顶点切石头（L2/L3 已教时机）高速坠落砸穿整缝脆板天窗（阈 14/石坠 15+，皮球不切 12 破不了）；b 套件扩至 **13/13 全绿**；新机制能力=每关脆板阈值可覆盖（fragile.speed）。探索内容不并入基线。
- **v10 = Batch 01 基线（冻结，试玩链接钉死 play.html?id=demo-02-3d-v10）**；本轮按用户「没活干就做更多机制关卡」指令产出 **L6 抛接峡谷（探索版 demo-02-3d-v11，直链可达 https://tonyguan530.github.io/taptap2026/builds/demo-02-3d-v11/index.html ，hub 槽未切）**：羽毛斜抛空中转向接力浮空弹板二次点火抛上基座，石头直线弹道对照失败；b 套件扩至 11/11 全绿。L6/L7 探索内容不并入基线，Batch 01 数据回来后由督导定取舍。
- 本轮工程修复（6e90a38）：**换关球泄漏**（_spawn_ball 未入 level_nodes → 旧球成物理幽灵与真球互撞毁发射，v10 亦带此 leak，v11 修复）；**弹簧点火改每帧 overlaps_body 查询**（body_exited 事件在斜抛+CCD 下延迟/丢失，spring_ready 永不再武装）；**触发带 0.4→1.2m**（高反弹微弹跳帧运气漏接）。
- 新增工程坑：①超时杀壳会泄漏 Godot 子进程（taskkill 按两个镜像名各杀一次）②硬杀损坏 .godot 缓存 → 引擎初始化 100% CPU 死循环且日志文件都不建 —— 删 game/.godot 重建即愈 ③同帧 queue_free 的节点 dump 仍在 children 里（别当幽灵 bug）。
- **ChatGPT 专属监督对话 URL（定时任务提示词 2026-10-05 补记）：https://chatgpt.com/c/6abf238d-6dc0-83ec-aa5e-43c62aebe892** —— 2026-10-05 收官评审因侧边栏找不到该线另开了新对话 https://chatgpt.com/c/6ac2d990-1b54-83ec-aa58-aca4ab18859d ，后续里程碑优先用专属线。
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
