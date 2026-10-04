# demo-08 纸飞机折线设计 · 3D 迁移专属自动化对话创建包

> 用法：开一个 ZCode 聊天，把本文件「——」以下的全部内容原样粘贴发送即可。该聊天将成为 demo-08 的专属开发对话，并创建自己的定时任务（每 30 分钟一轮，每小时 :00/:30 触发）。
>
> 依据：用户指令 2026-10-04「这是指南，修改定时任务内容去完成指南上的；如果没活干了就做更多机制关卡。」3D 迁移使命完成后 fallback = 更多机制关卡。
>
> **已创建（2026-10-04）**：任务名「每30分钟：demo-08 纸飞机 3D 迁移与关卡扩展」，cron `0,30 * * * *`，ID automation-1d162838-abcf-40cb-9106-be054cc37074，常驻于创建它的 ZCode 会话（D:\GIT 工作区）。

---

创建一个定时任务（cron 表达式：`0,30 * * * *`），任务名：**每30分钟：demo-08 纸飞机 3D 迁移与关卡扩展**。

你是 TapTap2026 项目 demo-08「纸飞机折线设计」的专属自动化开发对话，使命：按 3D 指南完成 DEMO8 的 3D 化迁移与持续迭代。仓库主工作区 D:\GIT\taptap2026（Bash 可用，PowerShell 用 powershell -File 调），DEMO8 专用 worktree D:\GIT\taptap2026-demo08-3d（分支 demo08-3d）。每 30 分钟一轮，按以下流程执行。

## 必读
- 指南（必读，含阶段 A~D、验收矩阵、规则不变量、首阶段提示词）：D:\GIT\3D-GUIDE\taptap2026-demo08-3d-zcode-guide-2026-10-04.md
- 通用 3D 接入说明：D:\GIT\3D-GUIDE\README.md 与 DEMO2 指南（工具配置参考，玩法以 DEMO8 指南为准）
- 每轮开始先核对：worktree 的 git 状态与 HEAD commit；guides 是否有更新版本

## 关键路径与状态
- 3D worktree：D:\GIT\taptap2026-demo08-3d（分支 demo08-3d，自 main @ 29b937c 创建，2026-10-04 就绪）
- 旧 2D 版对照（冻结不改）：game/demo08_paperplane.gd/.tscn + game/tests/test_demo08*.gd
- 新文件约定：game/demo08_3d.tscn、game/demo08_3d/、game/assets/demo08_3d/、game/tests/test_demo08_3d*.gd
- 禁止混用其他 demo 的 worktree（demo-03 → taptap2026-demo03-3d，DEMO2 → taptap2026-3d）
- public/demos.json 当前指向 demo-08-v3；未来建唯一 demo-08-3d-v1+ 构建

## 使命（阶段 A~D，细节以指南为准）
- **阶段 A 规则基线与跟随灰模**：独立入口；折线参数/飞行状态/关卡经济/可视网格分离；L1+L2 最小完整局（折纸→投掷→飞行→结算→商店）；CameraRig→SpringArm3D→Camera3D 跟随机位（不继承滚转、不改模拟、提供复位）；米制表现 60px=1m，X 侧向/Y 向上/-Z 前进，先旧单位积分+表现层转换。完成边界：相同折线/角度/充能/delta 下参数、轨迹、币数与旧版对照一致；真实点击与按键可完成一局。
- **阶段 B 真正三维飞行**：A/D 有限侧向转向、横向场地、三维门与遮挡；对照无输入基线；转向不得隐性刷升力或里程；三策略仍可成立。
- **阶段 C 五关与诚实资产**：五关 LEVELS 配置完整迁入（不删关）；门横向宽度、地形碰撞、低面数模型（Blender→GLB 可选，不必先用）、结算轨迹复盘小图。
- **阶段 D Web 与真人验证**：Compatibility/WebGL 构建、公网 iframe 实玩、字体子集核查、真人折法探索记录（不教标准折法）。

## 规则不变量（不得偷改；新增规则单独记录为规则变化）
- 折线（纸面右侧+升力）：lift_area += 0.45×(0.4+0.6×out)；trim += 0.35×vert（上正下负）；drag_f += 0.18×len_ratio
- 投掷：角 0—60°、充能 1.2s 满、力度截 0.05—1、初速 LAUNCH_V=1150px/s、起始高度 40/60m
- 飞行：升力封顶 0.95g（非旧注释 1.8g）、重力 380px/s²、阻力∝速度²、逆风阻力×1.25、顺风 +90px/s² 恒加速、40° 稳定减阻最大 0.2 线性衰减至 ±5° 为零
- 经济：门奖即时入 coins、失败保留不撤回；高低门一掷互斥（未领过才可判另一门）；成功结算 int(distance/10)+固定币、失败无结算奖；修正结算显示漏门奖=拆 gate_reward/finish_reward 显示，不改经济
- 商店：最多 3 件、购后移出不补、唯一不重现；力气 1+0.2n、翼面 1+0.15n 线性叠加；螺旋桨 120px/s² 恒推、配平仪偏转减半、韧性每掷一次弹跳（-abs(vy)×0.5-60，前进×0.8）
- 结算优先级：终点 > 落地 > 14 秒超时；韧性只弹一次
- 五关配置：L1 30m 无风 / L2 45m 逆风高低门 / L3 65m 顺风 / L4 55m 逆风双门互斥 / L5 85m 顺风高门；首阶段未迁移的关卡明确列待办，不得改写"五关已完成"

## 每轮流程
1. 环境与基线：cd D:\GIT\taptap2026-demo08-3d\game，Godot headless 跑 game/tests/test_demo08_3d*.gd（失败必须返回非零退出码；固定 delta、正常 time_scale=1、真实输入序列，不只用内部 API）；MCP Pro 每次先确认连接到本 worktree 的 game 目录（Godot 用用户指定 Steam 路径），连错目录立即停手
2. Miro 同步：node tools/miro-fetch.mjs；data/db.json demo-08 反馈；Miro 想法与 GitHub 玩家反馈 Issues 同级进入统一队列（记录来源/ID/原文/验收场景），更新 requirements/backlog.md 的 demo-08 节
3. 开发：按当前阶段推进最小可验收切片；迁移新增规则（门宽度、侧向阻尼、最短线长等）单独记录
4. 发布（仅当有可玩增量）：切 project.godot main_scene → --import 校验 → powershell -File tools/export-web.ps1 -Version demo-08-3d-vN（只在 demo08-3d worktree 执行，它会重写 selected_scenes 预设）→ node tools/publish-qa.mjs <version>（FAIL=CDN 传播中，等 2-3 分钟重试；持续 FAIL=itch 平台故障，改发 GitHub Pages 并记录）→ powershell -File tools/push-itch.ps1 -Version <version>；builds/ 只保留最新 1-2 版（Pages 1GB 软限事故教训）
5. 验证一律走公网（Pages play.html?id=<slot> 或 itch 页面），禁止内嵌浏览器/前端实测（IAB 渲染节流不可信）；截图/录屏用 Godot Movie Maker 离线渲染
6. 评审：ChatGPT 专属对话发背景+截图+链接，回复存 reviews/chatgpt-demo-08-3d-*.md 并更新映射
7. 收尾：demos.json 更新、git push origin demo08-3d（主工作区只提交 automations/backlog/报告类文档）、reports/ 报告（注明阶段、证据、剩余待办）、中文简短汇报。绝不把 data/secrets.json 内容写进报告或提交

## 本 demo 已知坑（务必遵守）
- 【单位换算】表现层 60px=1m；旧核心先按原单位积分再转换；LIFT_K_m=0.057、DRAG_K_m=0.0054、重力 6.333m/s²、顺风 1.5m/s²、螺旋桨 2m/s² 是等价推导，不得套 Godot 默认重力
- 【禁止双更新】不得同时让旧积分与 RigidBody3D 各算一遍；CharacterBody3D 用 move_and_collide() 自定义撞地结算，防贴地滑行
- 【高速门漏判】用前后位置线段与前进平面求交点判门，不靠单帧 Area3D 重叠
- 【相机】不挂滚转机体下；镜头碰撞不改飞行结果；默认关强震屏/大幅动态 FOV
- 【真实输入】现有测试全是内部 API 直调，不能证明 Control 布局、蓄力、相机、3D 转向可用；新增回归必须真实点击/按键
- 【时间口径】v1 测试 Engine.time_scale=6 与正常时间不可混比；发布验证一律 time_scale=1
- 【Godot 严格模式】clamp 返回 Variant 需显式 : float；Control/CanvasLayer 类型不可混赋

## 无活即转向（用户指令：更多机制关卡）
3D 四阶段全部完成且评审无阻断项时，或当前阶段被外部阻塞（平台故障/等待用户决策/等评审）连续 2 轮无实质进展时，按序 fallback，不许空转：
1. **更多机制关卡**：用现有机制在 LEVELS 表加 1-2 关（新纸张比例、风型、门组合），headless 平衡测试双用例（合理折法可过 / 摆烂不可过），记录为规则/内容变化
2. 扩展玩法组合：评审约束内（如新商店物品、新门类型、风切变）
3. 迭代美术/反馈：粒子、转场、UI 润色（绿幕管线见 automations README）

转向时在报告注明「停滞转向：demo-08 → 阶梯项」。
