# demo-06 3D 真人盲测执行手册（L3 主 Gate · failure_cause 版）

- 适用构建：**demo-06-3d-v6 起**（boots 直进 L3 主 Gate；Pages：https://tonyguan530.github.io/taptap2026/builds/demo-06-3d-v6/index.html ）
- 依据：reviews/chatgpt-demo-06-3d-phaseabc.md（3D KEEP + L3 校准完成 + control friction 分类 + Object Lifecycle 观察轴）
- 人数/时长：5~8 人 × 单人 ≤10 分钟；一人一 sid（构建自动生成，J 键可查）

## 开场白（照读，不提示任何解法）

> 这是一个第三人称小实验。你可以移动、跳跃（WASD/空格），鼠标控制视角。数字键 1/2/3 选形状，4/5/6/7 选"词条"，Q/E 旋转，滚轮调远近，左键把选中的东西放进世界。放进世界的东西遵循物理规则。目标：让小恐龙到达对面的黄色目标区。墨水有限，放东西会消耗。卡住了可以按 R 回到起点、T 重开本关。请边玩边把你的想法说出来。

不告知：有几条路线、词条语义细节、沟宽、评分标准。

## 操作速查（可印给受试者）

WASD/空格移动 · 鼠标视角 · 1/2/3 形状（球/板/块）· 4/5/6/7 词条（4=Heavy 5=Float 6=Fire 7=Sticky）· Q/E 旋转 90° · 滚轮 3~8m 放置深度 · 左键放置 · R 复位（不退墨）· T 重开本关（退回初始）· J 复制遥测 JSON · Esc 释放鼠标

## 组织者记录表（每人一行）

- sid / 开始时间 / 用时（到 GOAL 或放弃）
- 首解路线（目测：架桥/垫块/推箱/其他 D）+ 是否用环境箱
- placement_rejected 次数（J 导出的 JSON 里数 `placement_rejected` 事件；≥3 次即标 placement_control 疑似）
- **failure_cause（每次卡住人工标一项）**：`system_reasoning`（没理解词条/目标）· `placement_control`（想到了但 ghost 位置/深度/旋转放不对）· `movement_camera`（镜头/移动操作问题）· `unclear`
- **lifecycle mental model（口供原话记关键词）**：是否出现"结构件（Float）/延迟固化（Sticky）/消耗品（Fire）/能滚的工具（Heavy Ball）"类表述
- 墨水剩余 / 重开次数（JSON `reset`/`session_end`）

## 数据回收

- 每次放置/尝试/拒绝/接触/复位/通关都实时写入遥测；**J 键把完整 JSON 复制到剪贴板**，粘贴到 `reviews/blindtest-3d/<sid>.json`。
- 文件亦在 `user://demo06_3d_tel/tel_<关卡>_<sid>.json`（Web 下存 IndexedDB，刷新不丢）。
- JSON 结构：`{"pid":"demo06_3d_L3_<sid>","events":[{type,ts,el,sid,level,...}]}`；事件类型：`start/select/placement_attempt/place/placement_rejected/contact/reset/goal/session_end/restart`；`goal` 事件含 elapsed/ink_left/placements/**ghost 终位**（pos/yaw/深度）。
- `tools/blindtest_summary.mjs` 已适配 3D（自动识别 `demo06_3d` pid）：逐会话 Gate 行（通关/用时/放置/拒绝比/复位/**重开**/墨余/组合/ghost 终位）+ 聚合（通关率/中位用时/拒绝率）。failure_cause 与 lifecycle 口供不在遥测内，由组织者表补充。
- 口径：T 重开后 el 归零、同 sid 文件含多段尝试（`session_end:restart` 分隔）；用时只取 goal 事件的 el；重开次数单列不混入失败统计。

## 协议红线

- 不演示、不给解法提示、不评价玩家选择；卡住 ≥3 分钟且受试者想放弃时才允许说"可以按 T 重开"。
- usability 观察（placement_control/movement_camera）与涌现结论分开统计，不混算（评审裁定）。
- 非通关局：组织者在记录表标注 `session_end` 缺失原因（主动放弃/时间到），JSON 不做手动补写。
