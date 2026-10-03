# 督导指令 2026-10-04 04:40·重锚+停滞恢复（demo-05 专用·最高优先级）

> 本文件由总督导写入，demo-05 每轮第 3 步（反馈消化）必读本文件并优先执行。执行完成后在本文件末尾追加一行 `[DONE HH:MM 版本号]`。

## 督导现场核查（04:40）

- 工作区存在**未提交改动**：`game/demo05_volcano.gd`（mtime 04:07）、`game/tests/test_demo05.gd`（03:24）、`game/project.godot`。
- 03:19 触发的一轮已超长运行 80+ 分钟；04:07 后改码停滞、无 data/export.lock、无 Godot 进程（深夜 headless 停摆特征：进程已死但轮次未收尾）。
- 03:50/04:20/04:40 三槽未注册派发（长轮次合并排队）。

## 本轮必须执行（收尾优先于新开发）

1. `git diff game/demo05_volcano.gd game/tests/test_demo05.gd` 盘点未提交改动内容：
   - **改动完整**（灾害链内容增量、可编译）→ 跑 `game/tests/test_demo05.gd`（4 用例）+ `test_demo05_dominance.gd`（8 policy）双 PASS → 走发布流程（export-web → publish-qa → Pages 兜底验证）→ **重录 demo-05.mp4 + miro-post-shots 上板** → git 提交发布。
   - **改动残缺/不可编译**（引擎停摆打断）→ 放弃残改，按 reports/ 已有报告重建该内容增量（用新增数据项方式，不改既有 ROUTES/灾害数值）。
2. 收尾三件套照常：reports/ 报告、ChatGPT 评审存档、git push（只 add 本 demo 文件）。
3. 完成后在本文件末尾追加 `[DONE HH:MM demo-05-vN]`。

## 停滞恢复预案（用户 20:18 制定）

- 首选：扩展玩法——新增灾害事件类型（内容层，不动 V8 平衡参数）。
- 次选：补充关卡——新路线分支。
- 再次：迭代美术——dino.png 绿幕素材部署（ChatGPT 生图 #00ff00 → 抠绿 → 透明 PNG，参考 green-screen-sprite-workflow）。
- 转 3D：不适用。

## 不变约束

V8 平衡参数与 cave tax 2食2水 冻结、禁 V9 数值调参、≥5 递进阶段硬目标、视频必须最新版（03:00 指令）全部维持。
