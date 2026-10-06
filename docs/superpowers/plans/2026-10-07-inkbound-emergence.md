# INKBOUND 形状与词条首个切片开发计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在一块开放场地中完成真实绘画、拾词、结构兼容、两槽授能和送回实体页匣的五分钟试玩。

**Architecture:** 新增独立 V11 场景。结构分析不授能；能力组件读取结构特征及真实环境；目标只读取页匣的真实位置与稳定状态。复用 V10 多笔画纸、角色、美术与触控输入，保留旧导出与录像。

**Tech Stack:** Godot 4.7.2，3D世界＋2D画纸/UI，GDScript，headless 原生验证与 Chromium 浏览器实际输入验证。

**Spec:** `docs/inkbound-emergence-redesign.md` 与 `docs/inkbound-gd-writer-review.md`。

## Global Constraints

- 墨色不限制用途；原笔迹不能被预制物品替换。
- 首日只有可攀爬、漂浮，两词槽；黏附后续独立开发。
- 无词不能主动攀爬；形态判定成功不能自动授能。
- 合法解法不依赖物品类别、词条名称或路径顺序的成功白名单。
- 手机横屏、大画纸、点控、有限旋转按钮；不加入自由镜头与多指变换。
- 一律 headless，不开 Godot 编辑器／游戏窗口；保持共享配置、其他游戏和旧版发布不变。

## Review Focus

- 无词梯架、带词不兼容形状与同词不同形状：拒绝或生效原因清楚，画稿保留。
- 两词重复／换序／去掉一词：组件不重复注册、不相互覆盖、不偷偷重画。
- 站在移动浮物与攀爬出口：真实支撑、负载、身体空间与失效恢复一致。
- 旋转、回收、失焦、画纸开关、多指：不串输入、不回收脚下支撑导致无恢复。
- 正面、侧坡、绕行与意外搭建：目标只检查真实页匣结果，输入录像不能被当成涌现证明。

## Task 1：结构分析与词条授能

Files: `game/v11/drawing_structure.gd`、`game/v11/ink_capabilities.gd`、`game/tests/test_ink_v11_capabilities.gd`。

接口：`DrawingStructure.analyze(strokes: Array) -> Dictionary` 保留原笔迹、米制几何与结构特征；`InkCapabilities.evaluate(structure: Dictionary, words: Array, unlocked: Array) -> Dictionary` 返回已激活组件及按词条索引的拒绝原因。首片词条内部键为 `Climbable`、`Floating`；最多两个不重复词。结构分析不得返回已经激活的攀爬行为。

- [ ] 写失败测试：同一梯稿无词不可爬，有可攀爬才授能；未拾词不可用；缺支点反馈明确。
- [ ] 运行 headless 确认失败后，实现保留原笔迹的结构结果与兼容接口。
- [ ] 测试梯架、节点绳、网架复用攀爬组件；拒绝物品名称白名单。
- [ ] 验证两槽重复、换序、卸词与画稿保留，提交已验证的任务文件。

## Task 2：动态画作、搬运与浮力

Files: `game/v11/ink_body.gd`、`game/v11/ink_water.gd`、`game/tests/test_ink_v11_physics.gd`。

接口：`InkBody.configure(structure, capability_result)` 由同一份结构创建网格与碰撞；换词重新配置组件并保留实体姿态。`InkWater` 只向实际浸水的动态画作提供水位与浮托状态。沿用画纸 24 笔／每笔 256 点的上限，活动画作最多六件；超限给出反馈并保留原稿。

- [ ] 写失败测试：原轮廓与凹口保留，落下／推移／普通承重可见；动态形状使用复合凸碰撞。
- [ ] 实现有限动态画作、平放／立放、搬运、放下、回收与安全复位。
- [ ] 实现漂浮组件，验证水中浮托、超载下沉、同稿移除词后失效。
- [ ] 验证可攀爬＋漂浮的支点随实体移动、出口支撑和恢复；性能不稳定则停止扩展。

## Task 3：开放场地与教学

Files: `game/v11/ink_lab.gd`、`game/v11/ink_lab.tscn`、`game/tests/test_ink_v11_lab.gd`。

- [ ] 构建浅池、正面高台、侧面低坡、起点可达词条和一个实体页匣。
- [ ] 目标检测只检查页匣到达与短暂稳定停留；不检查类别、词条或路径顺序。
- [ ] 复用 V10 画纸与点控；无词／兼容／生效三态有清晰反馈，失败保留画稿。
- [ ] 三句以内的环境叙事与结果小纸签；不增加指定组合箭头或逐段开门。

## Task 4：输入、自由试验与发布

Files: `tools/export-inkbound-v11.ps1`、`tools/verify-inkbound-v11-web.mjs`、`docs/inkbound-v11-validation.md`、独立 build 与入口。

- [ ] 跑原生测试、headless 导出；确认 exit 0 与实际产物。
- [ ] 用真实桌面与触控输入录制至少三条测试情景，验证原画、两槽、运输和结局，无状态写入捷径。
- [ ] 获取陌生玩家自由试玩证据；如只能照提示做，修改场地／规则，不扩世界。
- [ ] 明确标记尚未取得真人反馈的部分。精确提交并发布，确认 Pages 成功和线上实际 PCK 一致，再更新 Miro。

当前状态：评审与计划已完成；以上实现任务均未完成。V10 触控补丁另行验证和发布。
