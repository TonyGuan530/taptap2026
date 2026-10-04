# demo-03-3d v8+v9 备案草案（待发送 · 因"不弹窗不占鼠标"约束推迟；v4~v9 六份一并发出）

> 发送渠道：ChatGPT 专属对话 https://chatgpt.com/c/6ac0e8c8-f34c-83ec-9c30-1cca9503c042
> 配图：reviews/shots/browser-smoke-v9/（真实 Edge headless 运行截图，可随备案发出）
> 发送后：回复存 reviews/chatgpt-demo-03-3d-vN-full.md 并更新 reviews/chatgpt-conversations.json

---

【demo-03 3D 线 v8+v9 备案】（阶段 D 闭环）

背景：v4 灭火指挥 / v5 风暴 3D 辨识 / v6 寒夜守卫第 2 章 / v7 结算遥测之后，本轮落地阶段 D 的 headless 浏览器冒烟（playwright-core + Edge headless，无窗口），并修复它揪出的两类 Web 端显示缺陷：

1. v8：Web 端 emoji 全缺字（浏览器渲染无系统字体回退，桌面 CLI 截图一直正常所以此前未发现）→ UI 文案全部改为字库内汉字标记。
2. v9：字体子集缺 3D 线新增用字（挥/卫等，2D 时代裁的子集没重跑）→ 重跑 subset-font（1676 字符）。

v9 复验：三模式真实点击进入对局、0 页面错误、文案渲染正常（附截图）。规则零改动；模拟 73 / 输入 28 / 场景 12 断言全绿。demos.json 已切 demo-03-3d-v9。

问题：
1. 阶段 D（构建与反馈闭环）在此约束集下是否可视为完成？（浏览器实玩=Edge headless time_scale=1 + 截图证据；Playwright 真人级操作路径已覆盖菜单进入）
2. 真人盲测前是否还需要本轮次的督导回看（v4~v9 六份草案待发），还是直接进入盲测组织？
3. 结论：KEEP / ITERATE / DROP（对 v8+v9 增量）。
