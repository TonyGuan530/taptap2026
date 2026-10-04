# demo-03-3d v4 备案草案（待发送 · 因"不弹窗不占鼠标"约束推迟）

> 发送渠道：ChatGPT 专属对话 https://chatgpt.com/c/6ac0e8c8-f34c-83ec-9c30-1cca9503c042
> 发送后：把回复存为 reviews/chatgpt-demo-03-3d-v4-full.md 并更新 reviews/chatgpt-conversations.json

---

【demo-03 3D 线 v4 备案】（无图版：本轮禁弹窗，截图待可录时段补）

背景：v3（comic 风格场景应用，阶段 C 基本完成）之后，按用户 fallback 指令"更多机制关卡"新增主动技能。用户新约束：不再打开 Godot 前端/窗口化进程（Movie Maker、浏览器自动化均暂停），全链路 headless。

规则变化（纯新增，旧规则零改动）：
- 灭火指挥：F 键/HUD 按钮触发，花 25💧，8 秒全队降温 +1.5/s，冷却 20s。
- 设计意图：不吃酸雨乘区（塔 ×0.6 / 村民 ×1.5 不影响），定位"酸雨中的可靠工具"；与建设/升级/晋升共享水滴池，构成"建设 vs 急救"的资源决策。
- spend_log 新增 kind=command；HUD 按钮三态；菜单提示更新。

工程：
- 输入管线测试 headless 化：修复 stretch=canvas_items 下 headless 点击坐标错位（经 get_final_transform 映射窗口坐标），新增 F 键真实键盘事件断言；21/21 PASS，全程不开窗口。
- 模拟测试 38→56 断言全绿（对照局 8s 窗 -12 度、酸雨中 +1.5 固定不乘区、冷却/事件/边界）。
- 发布：itch html 通道 √ #2065479 = demo-03-3d-v4；发现 3D 线从未进 GitHub Pages（v3 404），本轮以 plumbing 提交把 v4 补进主仓 builds/ 并切 demos.json demo-03 → demo-03-3d-v4。
- 视频/Miro 与本备案发送本身按约束推迟。

问题：
1. 该主动技能对"涌现"目标是加分还是把 60 秒局变成固定套路（酸雨必按）？若冷却 20s/花费 25 出现"每场酸雨必交 25 水滴"的最优解，应调哪个参数恢复权衡（花费/冷却/时长/降温量）？
2. 阶段 C 收尾（Blender GLB 正式资产）与该技能哪个优先？
3. 结论：KEEP / ITERATE / DROP（对 v4 增量）。
