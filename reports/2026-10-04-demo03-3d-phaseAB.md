# demo-03 3D 迁移 · 阶段 A/B 报告（2026-10-04，v1 灰模可玩）

## 指令依据

用户指令：按 D:\GIT\3D-GUIDE\taptap2026-demo03-3d-zcode-guide-2026-10-04.md 将 DEMO3 迁移为斜俯视 3D 经营；定时任务已改写为该使命（automation-34978d28，每小时 :10）。

## 交付（demo-03-3d-v1 灰模可玩）

- **worktree**：D:\GIT\taptap2026-demo03-3d（分支 demo03-3d，已推 origin）；主工作区 2D v14 冻结为回归对照。
- **模拟核心**：game/demo03_3d/kingdom_simulation.gd（RefCounted，规则与表现分离）——温度 40 起/60 秒局/100 度失败/3 槽位/建造 20/升级 40/晋升 30/四职业（工程师-5、植物学家+0.4、气象学家减半、搬运工+1.5）/晋升一次+0.7/五阶段曲线（v7）/酸雨预警 3 秒与 ×0.6×1.5/经典 22·46s±3×8s/风暴 15·30·45s±2×4s/spend_log 保留。
- **灰模场景**：game/demo03_3d.tscn + demo03_3d/ demo03_3d.gd——正交斜俯视相机（俯角 50°/滚轮缩放 14~40/Q-E 旋转/Home 复位）、3 槽位射线拾取（Area/StaticBody+稳定 meta ID）、村民胶囊（职业色+Label3D+拾取）、四小屋+暖窗、火山锥+火口辉光、岩浆发光面、酸雨 CPUParticles（Compatibility 友好）、HUD（温度条/水滴/时间/五段进度条/阶段横幅/酸雨预警与进行横幅/风暴徽标）、菜单（经典/风暴双模式按钮）、结算面板（再守一次/选模式）。
- **测试**：game/tests/test_demo03_3d.gd——38 项断言全 PASS（P1 解析对照/摆烂 20~30s 败/会玩 60s 胜+两村民+晋升+两场酸雨起止/风暴 3 场+win/气象学家减半对照/工程师折扣扣费/植物学家降温/搬运工收入/资金不足不扣费/满级/胜利后禁操作/spend_log 有序）；**失败退出码 1**。

## 发布

- itch：demo-03-3d-v1 已推（频道头=v12 被后推轮转时以 butler 历史为准，可随时重指）；publish-qa 记录 FAIL（itch CDN 占位页已知故障，非本构建问题，未反复重推）。
- Pages：v13 起部署恢复；3D 构建入 Pages 待合并 main 后随站点发布（demo-03 旧构建已自瘦 600MB，全库清理待用户决策）。
- 本地可玩：worktree 内 `godot --path game`（main_scene 已切 demo03_3d.tscn）。

## 已知边界（下一阶段）

- 阶段 B 剩余：真实鼠标拾取的编辑器/浏览器实测（当前以射线查询代码+sim 命令测试覆盖逻辑，GUI 点击实测待 Godot MCP 接入 worktree）。
- 阶段 C：Blender 正式资产替换灰模（GLB → game/assets/demo03_3d/）。
- demos.json slot 暂保持 2D v14；3D 完成阶段 C 后切 demo-03-3d-vN。
