# 督导指令 2026-10-04 19:30·3D/HD-2D 迁移阶段启动（用户指令·项目方向升级）

> Codex 已交付全部迁移指南（`D:\GIT\3D-GUIDE\`，2026-10-04 版）：demo-02/03/04/05/06/08/09/10/11 共 9 份，方向均已由用户选定。项目目标=**逐步全面 3D 化**（demo-01 现有 3D 成果保留不动）。本批示分派到各任务，自下轮起执行。

## 各任务对应指南（开工必读自己那份）

| 任务 | 指南路径（D:\GIT\3D-GUIDE\） | 已定方向 |
|---|---|---|
| demo-02 | taptap2026-demo02-3d-zcode-guide-2026-10-04.md | 第一人称物性解谜 |
| demo-03 | taptap2026-demo03-3d-zcode-guide-2026-10-04.md | 斜俯视 3D 经营 |
| demo-04 | taptap2026-demo04-3d-zcode-guide-2026-10-04.md | 第三人称 3D |
| demo-05 | taptap2026-demo05-hd2d-zcode-guide-2026-10-04.md | HD-2D 恐龙生存（饥荒×环世界感，直接操控恐龙） |
| demo-06 | taptap2026-demo06-3d-zcode-guide-2026-10-04.md | 见指南 |
| demo-08 | taptap2026-demo08-3d-zcode-guide-2026-10-04.md | 见指南 |
| demo-09 | taptap2026-demo09-3d-zcode-guide-2026-10-04.md | 见指南 |
| demo-10 | taptap2026-demo10-3d-zcode-guide-2026-10-04.md | 见指南 |
| demo-11 | taptap2026-demo11-3d-zcode-guide-2026-10-04.md | 见指南 |

## 实施约定（各指南共性，必须遵守）

1. **专用分支/worktree**：按指南建立 demo 专用迁移分支或 worktree，记录绝对路径；**不动 main 的 2D 现役版本**（Pages 线上版继续由 2D 分支发布）。
2. **开工先重读**：指南核查基于历史快照——执行前先 git log/status 重读最新代码，不把历史裁决当新指令。
3. **阶段推进**：灰模可玩 → 五关迁移 → 模型制作接回 → 试玩反馈流程。每轮 30 分钟推进一个可验证的小阶段（持续开发令继续生效）。
4. **既有约束延续**：≥5 关内容量、视频重录上板、headless 测试门槛、遥测、git 只 add 本任务文件、绝不碰 data/secrets.json。
5. **2D 对照保留**：旧版完整保留（ Pages 线上版+git），迁移期玩家仍可试玩 2D 版。
6. 指南中「迁移建议」部分可结合实际调整，但「现有事实」（当前函数/机制）以代码为准。

## 督导侧同步调整

- 督导巡查降频为 **每 1 小时一次**（用户指令；调度变更需在 Automations 界面手动修改——督导侧无 CronUpdate 工具）。
- 各 demo 任务 30 分钟错峰维持不变（3D 迁移期工作量大，保持推进节奏）。
- Pages 发布继续走 2D 现役分支；3D 迁移分支验收后再切主线（切换时督导另发裁决令）。


---

## 增补（19:40·用户指令）：统一美术基线 Low-poly/Comic Kit——全项目强制，未完成持续催办

**用户已确认**：D:/GIT/3D-GUIDE/low-poly-comic-kit/ 为全部 DEMO 的统一美术基线（低面数+纯色+漫画轮廓，已在原生 Compatibility 与 Edge WebGL2 跑通验证）。

### 各任务接入要求（并入每轮工作，未完成督导持续催办）

1. 规范入口：D:/GIT/3D-GUIDE/taptap2026-unified-low-poly-comic-style-2026-10-04.md（决策）+ low-poly-comic-kit/ZCODE-MODELING.md（建模规范）+ low-poly-comic-kit/README.md（套件使用/复制方式）。
2. 材质/描边直接复用套件：comic_style/shaders/plain_toon.gdshader（纯色两档面光）、pixel_outline.gdshader（反向外壳描边：交互物 4px 深墨粗线/场景 1.5px 细线/悬停暖色 4px/选中 5px/临时不可执行灰墨保类别）、sprite_comic.gdshader（HD-2D billboard，demo-05 专用）、comic_style/comic_style.gd（颜色线宽 Resource）。
3. 基础模型八类（箱/铁块/岩石/树/灌木/木桶/压力板/门框）直接从套件取用；新模型沿用同一形体语言，GLB 经 ComicObject.add_imported_model 接入（单材质/封闭分件）。
4. **demo-05 特例**：HD-2D 恐龙角色保留（sprite_comic+Y 轴 billboard），环境用统一 low-poly 材质。
5. 描边语义按交互状态区分，材质只表逻辑状态；碰撞/拾取/导航由各 demo 玩法层实现。
6. **验收口径**：各 demo 的 3D 迁移里程碑需含「美术基线接入完成」检查项；督导巡查逐轮核对，未接入的 demo 持续催办（并入队列/催办体系）。
