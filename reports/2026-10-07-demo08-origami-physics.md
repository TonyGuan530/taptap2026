# demo-08 v27：折纸与五关物理试飞

用户要求归档 08—2D，直接修复 3D 折纸和纸飞机物理，随后明确只保留五关。

## 结果与范围

- 2D v3 撤出大厅并标为 archived，旧构建保留可恢复。
- 3D v27：由纸面多边形切分和绕折痕旋转生成 ArrayMesh，五步示范折出尖头与机翼；同一折后几何用于世界、独立预览和飞行。
- 手动折痕、逐步动画、回退一步、重新展开；自由试飞落地后保留折法，可回退修改。
- 默认进入自由试飞；选关器只提供下列五个正式挑战，逐关解锁。通关直接下一关，失败重试，第五关总成绩。
- 新物理使用米、千克、秒：80gsm 原纸质量守恒；外露面决定有效翼面，重心与近似惯量随折法变化；相对风速产生升力、阻力、力矩与失速；240Hz 子步积分三维姿态。A/D 施加转向力矩，S 施加俯冲力矩。

| 关 | 挑战 | 目标 | 风 | 已验证操作 |
|---|---|---:|---|---|
| 1 | 折出机翼 | 12m | 无 | 示范折法、12°、满力 |
| 2 | 低抛更远 | 16m | 无 | 示范折法、12°、满力 |
| 3 | 顶住逆风 | 9m | 逆风 2m/s | 示范折法、12°、满力 |
| 4 | 侧风漂移 | 13m | 右侧风 1.5m/s | 示范折法、12°、满力，不必强制转向 |
| 5 | 顺风投递 | 20m | 顺风 2m/s | 示范折法、12°、满力 |

## 开源方案与模型边界

[Origami Simulator](https://github.com/amandaghassaei/OrigamiSimulator) 是 MIT 的弹性折纸参考，但其 WebGL/GPU 求解体系不适合本次快速 Godot 修补，因此未接入。

实际复用 [Addmix Godot Aerodynamic Physics](https://github.com/addmix/godot_aerodynamic_physics) 的 MIT 升力曲线，并改写其动压升阻力与作用臂力矩计算。原始来源、版本和许可证在 `game/demo08_3d/vendor/`，Web 构建附许可证。

本次实现是刚性纸面铰链折叠和近似三维气动力；不包含柔性纸材应力、自碰撞/接触或 CFD。任意手动折痕作用于平叠纸面；机翼打开后需先回退这一步才能继续改折。场景障碍保留作视觉布景，落地由实际三维高度判定，关卡到达距离旗即结算。当前未暴露旧商店，避免把不适用于新模型的参数强化呈现给玩家。

## 验证

- Godot MCP Pro 已连接隔离工程；纸面几何、气动力、表现脚本编译验证通过。所有 Godot 进程使用 headless。
- `test_demo08_paper_physics.gd`：实际顶点翻折、面积/质量/边长守恒、回退、五步折法、遮盖层不重复提供升力、相对气流阻力、失速、不同折法轨迹差异、30/120fps 轨迹一致。
- `test_demo08_paper_five_levels.gd`：真实 3D 模型连续通关五关，下一关/末关完成状态；40° 高抛在第二关失败，低蓄力在第一关失败，同关重试有效。
- `test_demo08_paper_real.gd`：实际场景 ArrayMesh 替代 BoxMesh、五步动画、回退可编辑、起飞落地、返回自由折纸保留上一架。
- 独立代码审查发现并修复「按住 A/D 返回菜单再投掷残留转向」；审查者独立 headless 复现确认，场景回归新增真实按键跨菜单检查。最终 native 30/20/6 项检查通过，证据 `reviews/demo08-physical-validation.json`，审查 `reviews/demo08-physical-code-review.md`。
- 无风满力：平纸 12° 9.38m；示范折法 12° 19.51m，8° 20.55m，40° 13.45m。折法与角度实际改变轨迹。
- 浏览器使用 headless Edge 真实点击/键盘操作；截图检查预览中有纸面且无占位纹理；自由试飞和五关流程记录在 `reviews/demo08-physical-browser-local.json`。线上复测在发布后记录为 `reviews/demo08-physical-browser-online.json`。
- `tools/export-demo08-physical.ps1 -Rebuild`：独立最小工程，导入与导出 exit=0，HTML/JS/WASM/PCK 全部存在；没有打包 MCP 插件或修改其他 Demo 的默认场景。

试玩：<https://tonyguan530.github.io/taptap2026/builds/demo-08-3d-v27/index.html>。
FB-104/109 维持 responded，等待真人复测，不代写 KEEP 或验收通过。
