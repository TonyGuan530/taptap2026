# demo-08 3D 迁移 · 第 4 轮（基座接入 + 阶段 B1：A/D 有限侧向转向）

日期：2026-10-04。执行：demo-08 定时任务 automation-1d162838。含用户轮中指令执行。

## 用户指令执行（本轮最高优先级）

「迁移分支一律从 3d-shared 拉出（不再各自复制套件），只做场景应用（世界物体换 ComicObject/统一材质）」

1. **换基座**：demo08-3d 已 `git rebase 3d-shared`（8458ca0，督导落位的 Low-poly/Comic Kit：comic_style 3 着色器 + ComicObject/样式/模型库 + models 八类 GLB），4 个提交无冲突重放，新 HEAD 线系于基座。后续拉新迁移分支将直接自 3d-shared 拉出（本次为存量分支换基，push 用 --force-with-lease）。
2. **场景应用**（demo08_3d.gd 世界重构，_flat_mat 自制材质全部删除）：
   - 高门 → 基座 `gate_frame` 模型（缩放到门宽 6m × 门高）；
   - 起点台 → 基座 `crate`；跑道两侧 10 个装饰 → 基座 `tree/bush/barrel/rock` 确定性摆位（速度可读性）；
   - 终点旗门、低门、纸飞机 → 自建 ComicObject `add_part` parts（统一 toon+描边，配色挂 ModelLibrary.COLORS）；
   - 大地面/跑道 → 统一材质 `ComicStyle.body_material()`，不加描边壳（巨型面描边出怪边，记为应用约定）；
   - 复验：8 张离线渲染截图更新（reviews/shots/demo08-3d/），飞行视角道具/描边/横移 HUD 全部可读。

## 阶段 B1 开发（规则变化 B1，单独记录）

**新增规则（不回改 2D 对照；无输入行为逐位不变）**：
- A/D 有限侧向转向：横向加速度 240 px/s²（按住）、速度上限 320 px/s、无输入阻尼 160 px/s²（HUD/菜单公开数值）；
- 升力仍按旧纵向/高度速度计算（不耦合，指南建议口径）；转向不改变前进/高度轨迹、里程、币；
- 赛道横向边界 ±20m：贴边 clamp、横向速度清零、前进继续；
- 门横向有效半宽 5m（GATE_HALF_PX=300）：穿越门位时 |lateral|>5m 不计门（与高度条件同帧判定；互斥规则不变）。

**证据**：
- `tests/test_demo08_3d_b1.gd`（headless）13 断言全绿：C2a 满舵 vs 无输入 109 步轨迹逐位一致（转向不刷里程/币）；C1 无输入横向恒 0 且 L2 高门结果同阶段 A（币 13）；阻尼单步衰减=160/60；速度全程≤上限；边界 clamp+前进继续；门出界不命中/界内命中 +3。
- `tests/test_demo08_3d_b1_input.gd`（窗口真实按键）8 断言全绿：按住 D 1s 横移 2.03m、HUD 横移显示、相机无滚转且半跟随（cam x=0.36m）、松开停住（0.5s 窗口 Δ0.052m）、转向后照常过关 30.1m。
- 场景 B1 表现：飞机偏航=航向角、小滚转倾斜（仅视觉），相机半跟随航向（无滚转）；trail 随横移平移（复盘小图留阶段 C）。

## 回归

| 套件 | 结果 |
| --- | --- |
| test_demo08_3d.gd（核心对照，headless） | 55 PASS / 0 FAIL（EXIT=0） |
| test_demo08_3d_scene.gd（真实输入，窗口） | 19 PASS / 0 FAIL（S9a 断言口径更新：L2 道具 9 松散节点→3 个 ComicObject，均含 parts） |
| test_demo08_3d_l2.gd（三策略，窗口） | 28 PASS / 0 FAIL |
| test_demo08_3d_b1.gd + b1_input.gd（新增） | 13 + 8 全绿 |

## Miro / 反馈

无 demo-08 相关新内容（pipeline 日志尾部为历史 itch CDN 故障噪音）。

## 评审 / 发布

- 评审包仍为 reviews/chatgpt-demo-08-3d-round03-package.md（本轮新增 B1 规则问题已列包内：侧向阻力口径按指南建议"升力不耦合+侧向独立阻尼"先行，待评审确认是否改全三维速度）。
- 发布未启动（阶段 D）；demos.json 不变。

## 待办（下轮）

- 阶段 B2：横向场地语义进关卡（L4 双门横侧位等，新配置字段单独记录）、遮挡处理、三策略在 B1 规则下复核（L2 三策略已在回归中保持成立）。
- ChatGPT 评审对话仍待建立（无浏览器授权）；材料已含 B1。
- git push --force-with-lease origin demo08-3d（rebase 改史，本轮已执行）。
