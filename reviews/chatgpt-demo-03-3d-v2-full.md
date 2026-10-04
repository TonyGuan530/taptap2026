# ChatGPT 监督评审 · demo-03 3D 阶段 A/B 备案（真实回复）

- 对话：https://chatgpt.com/c/6ac0e8c8-f34c-83ec-9c30-1cca9503c042 （demo-03 专属对话）
- 时间：2026-10-04 21:00 前后
- 备案内容：3D 迁移阶段 A（KingdomSimulation 模拟核心分离，规则逐项迁移，38 断言全 PASS）+ 阶段 B（真实鼠标事件拾取测试 17/17 PASS，InputEventMouse 走 Viewport→_unhandled_input→Camera3D 射线→Area3D 完整管线；悬停显示目标名称/价格/效果）；demo-03-3d-v2 推 itch+Pages；三点确认（阶段 A 验收/B 证据命名/C 约束）。

---

【ChatGPT 回复】（要点全文）

确认，当前仍是 **ITERATE**，但 3D 迁移本身判定为"迁移路线正确、A/B 阶段可通过"。原来的真人盲测 Gate 不取消，只应延后到 C/D 后、正式 3D 可读性基本定型时执行。

**① 阶段 A：规则对照验收 PASS。** 38 断言覆盖迁移必须保住的三层等价性：核心数值边界（40°C 起/60 秒/100°C 失败/价格/槽位/满级/资金不足）、时间系统（五阶段/酸雨预警起止/经典风暴事件结构）、职业与决策关系（×0.6×1.5/气象学家减半/会玩摆烂结果）。尤其不是只测"最后赢没赢"，而是包含解析公式对照、事件边界和非法操作——足以作为当前的 **Simulation Parity Gate**。建议把 A 从待办里正式关闭；后续 C/D 不能为了 3D 表现方便去改 KingdomSimulation（表现层只消费状态）。

**② 阶段 B：当前证据可接受为真实拾取链测试 PASS，但需准确命名。** 测试的是 InputEventMouse → Viewport → _unhandled_input → Camera3D ray → Area3D → gameplay action 的完整路径，价值远高于函数级测试。记成：**Engine-level Mouse Picking Gate：PASS**（而非 OS-level E2E Mouse Gate：PASS——后者等 Godot MCP/实际窗口自动化接入后补，不阻塞阶段 C）。

已覆盖的关键事故面：HUD 点击不穿透世界；相机旋转后射线正确；zoom 后正确；不同槽位不错选；钱不足无幽灵操作；reset 后状态正确。足以证明斜俯视 3D 基本 interaction model 无技术性硬伤。截图符合 B 阶段灰模预期（blockout，不应现在评美术完成度）。

非玩法阻塞记录：Pages /builds/demo-03-3d-v2/ 当时 404，发布渠道无法独立验证；不影响 A/B 设计裁决，后续检查部署路径。

**③ 阶段 C 开工前 4 条约束（比 GLB 好不好看重要）：**
1. **不要改变碰撞体来迁就模型轮廓**——visual mesh ≠ gameplay collider，Area3D/交互热区由玩法决定，否则阶段 B 已验证的拾取稳定性会重新失效。
2. **3D 不让信息密度倒退**——2D 视觉语义必须在 3D 成立：槽位一眼可找/L1L2 一眼可分/职业村民一眼可分/酸雨时设施弱村民强/可点击对象有明确 hover feedback。不能因为立体村庄让玩家"找按钮"。
3. **固定斜俯视可读性优先于模型真实比例**——正式 GLB 在"实际游戏相机+实际最远 zoom"下验收，而非 Blender 正视图；尺寸规则定死：最小 gameplay silhouette 默认视角保持清晰，职业识别靠大轮廓/大配件而非纹理细节（工程帽/风向标/背桶比衣服花纹可靠）。
4. **不要在 C 阶段顺便重做玩法布局**——先一对一资产替换（灰盒房屋→正式房屋/灰盒水塔→GLB 水塔/灰盒村民→GLB 村民），保持 transform/slot center/camera framing 稳定，否则无法判断 C 的问题来自模型/LD 重排/拾取变化。

C 验收 Gate 只看四件事：**Asset Replacement / Silhouette / Picking Regression / State Readability**。

真人盲测安排：同意等 C/D 完成后测 3D 最终形态；但**不能直接继承 2D 版"必然可读"的假设**——3D 版最终仍要重新验证同一核心问题：玩家在不接受外部策略解释的情况下，能否从 3D 场景、HUD、预警和状态表现中理解酸雨改变了设施/村民的相对价值，并主动改变资源投入。

当前备案：**阶段 A：PASS — Simulation Parity**；**阶段 B：PASS — Engine-level Mouse Picking**；**阶段 C：GO — 正式 GLB 资产替换**；OS-level E2E 输入：待补，非 C 阻塞项；**核心玩法：ITERATE**；最终 Gate：3D Final-form（原文截断处，结合上文为真人可读性盲测）。
