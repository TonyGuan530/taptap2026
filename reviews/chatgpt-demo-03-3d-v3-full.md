# ChatGPT 监督评审 · demo-03 3D v3 备案（comic 风格场景应用·真实回复）

- 对话：https://chatgpt.com/c/6ac0e8c8-f34c-83ec-9c30-1cca9503c042 （demo-03 专属对话）
- 时间：2026-10-04 22:00 前后
- 备案内容：按用户指令（迁移分支一律从 3d-shared 拉出，只做场景应用）——demo03-3d 分支合并 origin/3d-shared（comic_style 套件），世界物体 ComicObject 化（水塔 L1/L2、4 小屋、村民职业配色），统一 toon 材质 + ComicOutline 描边；零规则改动，38+17 断言 PASS；v3 推 itch+Pages。

---

【ChatGPT 回复】（要点全文）

备案确认。按汇报的实现范围，**阶段 C 可以视为基本完成，结论继续 ITERATE**。

这轮最关键的三件事都做对了：
1. comic_style 套件统一从 3d-shared 继承，没有在 demo 分支复制一套，后续维护成本可控；
2. 正式表现替换没有动 gameplay collider，38 条模拟断言 + 17 条拾取断言继续 PASS，阶段 A/B 的验证没有被美术迁移破坏；
3. 没有借 ComicObject 化顺手重排布局，保持"一对一视觉替换"，符合阶段 C 约束。

关于火山/岩浆：**不要求 ComicObject 化，建议继续保留程序绘制**。理由：它们承担环境背景和状态氛围，不是需要玩家精确识别、点击、比较的 gameplay object；强行纳入只会增加模型/描边复杂度，对核心可读性验证几乎没有新增信息。只要程序化背景在最终相机下与 toon/outline 前景不产生明显风格割裂，就属合理边界。

阶段 C 后续只盯两个风险：
1. 描边不要太粗——斜俯视缩小时，水塔支架、村民斗笠、水桶等细结构不能糊成一团；
2. 职业身份必须继续靠"大轮廓/大配件"成立，不能退化成主要靠身体颜色区分；酸雨 ▲/▼ 必须压过背景漫画描边的视觉噪声。

说明：督导侧当时无法独立拉取截图与 Pages 地址（双双 404，部署滞后），因此不把"comic 风格统一性视觉验收通过"写成独立确认，只确认实现方案与回归证据合格。

当前备案定为：
- 阶段 A：PASS — Simulation Parity
- 阶段 B：PASS — Engine-level Mouse Picking
- 阶段 C：基本 PASS — Comic 场景应用完成
- 火山/岩浆：KEEP 程序化，不要求 ComicObject 化
- 核心结论：ITERATE
- 最终阻塞：3D 最终形态真人可读性盲测

下一步不建议继续扩大 ComicObject 覆盖面。先把 D 阶段和最终 3D 可读性做完整，再进真人 Gate。
