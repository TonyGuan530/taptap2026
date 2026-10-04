# demo-08 3D 迁移启动交接（2026-10-04，用户指令：按指南迁移 + 更多机制关卡 fallback）

## 用户指令

「这是指南，修改定时任务内容去完成指南上的；如果没活干了就做更多机制关卡。」——demo-08 定时任务已创建为 3D 迁移使命（跟随纸飞机视角）；3D 完成后 fallback = 更多机制关卡。

## 关键路径与状态

| 项 | 值 |
| --- | --- |
| 迁移指南 | D:\GIT\3D-GUIDE\taptap2026-demo08-3d-zcode-guide-2026-10-04.md（必读，含阶段 A~D、验收矩阵、规则不变量、首阶段提示词） |
| 3D worktree | D:\GIT\taptap2026-demo08-3d（分支 demo08-3d，自 main @ 29b937c 创建，2026-10-04 就绪，801 文件已检出） |
| 主工作区 | D:\GIT\taptap2026（main；旧 2D 版 demo08_paperplane.* 与 test_demo08*.gd 冻结为回归对照） |
| 定时任务 | automation-1d162838-abcf-40cb-9106-be054cc37074（每 30 分钟 :00/:30，active，2026-10-04 创建；档位沿用 demo-01 让出的 :00/:30，与其余 demo 错峰） |
| 任务创建包 | requirements/automations/demo-08.md（含使命、每轮流程、已知坑、fallback 阶梯） |
| 相关 worktree | D:\GIT\taptap2026-3d（DEMO2）、D:\GIT\taptap2026-demo03-3d（demo03-3d）——DEMO8 禁止混用 |

## 使命摘要（细节见指南与定时任务提示词）

跟随纸飞机视角 3D 化：保留「折线设计→投掷→观察飞行→商店成长」循环。阶段 A 规则基线+L1/L2 灰模完整局（独立入口 game/demo08_3d.tscn，模拟与表现分离，CameraRig→SpringArm3D→Camera3D 跟随机位）；阶段 B A/D 有限侧向转向与三维门；阶段 C 五关完整迁入+资产；阶段 D Web 发布与真人验证。米制 60px=1m，X 侧向/Y 向上/-Z 前进；先旧单位积分+表现层转换。构建 ID demo-08-3d-v1+。

规则不变量以指南 §2 为准（升力封顶 0.95g、重力 380px/s²、投掷角 0—60°/1.2s/初速 1150px/s、40° 容错最大 0.2、门奖即时入 coins 失败保留、高低门一掷互斥、结算 int(distance/10)+固定币、商店不补货/线性叠加、终点>落地>14 秒）。任何新增规则（门宽度、侧向阻尼等）单独记录为规则变化。

## 本轮已完成

1. 创建 worktree D:\GIT\taptap2026-demo08-3d（分支 demo08-3d @ 29b937c）。
2. 写 requirements/automations/demo-08.md 任务创建包（demo-03 同格式）。
3. 更新 requirements/automations/README.md 表格（demo-08 行）。
4. 创建定时任务 automation-1d162838（cron `0,30 * * * *`，常驻 D:\GIT 工作区会话）。
5. 本报告。

## 待验证 / 后续轮次待办

- 尚未运行任何 Godot 测试或 MCP 连接；阶段 A 未开工。首轮应：确认 Godot（Steam 路径）headless 可跑 test_demo08*.gd 旧基线 → 提取折线/经济/纵向积分为独立核心 → 搭 game/demo08_3d.tscn 灰模。
- 3D 引擎侧一切结论（相机、米制转换、门判定）均为待验证；2D 历史测试不作为 3D 完成证明（指南 §0）。
- fallback 触发条件：3D 四阶段完成且评审无阻断，或外部阻塞连续 2 轮 → 更多机制关卡（LEVELS 加关+平衡双用例）。
