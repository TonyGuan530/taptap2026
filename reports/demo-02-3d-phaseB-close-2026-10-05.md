# demo-02 3D 化轮次报告（2026-10-05 晨）

## 结论速览
- **阶段 B 收官**：3D 版五关齐（demo-02-3d-v10 已上 GitHub Pages，build.json 200 验证）。
- **headless b 套件 9/9 PASS**（真实时间 time_scale=1，每用例独立进程）。
- **五关连打视频重录**（reviews/videos/demo-02.mp4，950 帧 / 32s，Movie Maker 离线渲染；L5 段遥测 idle=true 即零输入通关证据）。
- **ChatGPT 阶段 B 裁定**：阶段 B 收官冻结 v10；demo-02 总体 ITERATE；下一 Gate=Batch 01 真人试玩，不进阶段 C 美术（存 reviews/chatgpt-demo-02-full.md）。

## 本轮完成
1. **阶段 B 套件转绿**（此前多轮卡在 ③ 案静默挂）：
   - 根因一：b 套件 ③ 对准阈值是旧设计的（x≤-7.4），现行 L2 脆板错位在 x=-9.75 —— 球直上直下碰不到板。
   - 根因二：headless 长跑 physics_frame 停振 → 套件重构为**每用例独立进程**（`-- --case=N`），不再受长跑影响。
   - L2 设计余量重校：板厚 0.15→0.5（防 15m/s 穿板）、FRAGILE_SPEED 12→11、板压低 2.5→2.0、弹簧冲量按实测基准 12；加**未砸板不入洞**规则（滚落绕进无效，脆板语义成立）。
2. **两个真 bug（连带修出）**：
   - 碎板幽灵引用：板碎时 queue_free 但仍挂在 level_nodes，下次 _load_level 二次 free → 协程中断 → L2 后永远进不了 L3（套件每案新场景所以从未暴露；连打驱动暴露）。
   - 弹簧点火硬编码 (0,12,0)，LEVELS 的 imp 是死数据 → 接线为按关卡数据点火（全矢量，含横向分量）。
   - Dictionary.get 默认值急切求值：L4/L5 无 spring 键直接崩装载 → 显式分支。
3. **L4 开放高台（双路线）**：A=羽毛顶点转轻飘台；B=皮球按住 W 被空中弹板全矢量抛射（不换词条）。headless 双 PASS。ChatGPT 裁定：抛射路线保留（同一 mechanic 第二用途，不加词条锁；勿人工补第三条）。
4. **L5 高台弹跳（皮球零输入）**：竖直弹簧链逐级再点火（12 m/s 重置）穿高环；石头对照弹不上去。遥测 idle=true。ChatGPT 裁定：沿用 2D v7「KEEP AS TOY 勿修、不计 puzzle depth」。
5. **发布与素材**：v8→v9→v10 三次做完即传（每次 curl build.json=200）；五关视频重录；五关实机帧 reviews/shots/demo-02-3d-v10-L{1..5}.png；Miro 上板 demo-02-3d@(4400,6980)。
6. **评审**：ChatGPT 新对话收官评审（旧专属线滚出侧边栏无法定位），对话 https://chatgpt.com/c/6ac2d990-1b54-83ec-aa58-aca4ab18859d ，结论全文存档。

## ChatGPT 定死的 Batch 01 Gate（试玩判据）
- 升 KEEP：3-5 人中 L4 真实出现 ≥2 个 solution family，且 ≥1 人产出未预设合法序列；≥2 人在无解释下把前关物理关系迁移到后关。
- 继续 ITERATE：都能通但严格复现预设路线。
- 危险信号：玩家主要靠试遍 1/2/3 词条而非据运动结果形成物理假设。

## 下轮仅授权 3 件事（冻结 v10 前提下）
1. 冻结 v10 物理参数/五关结构/三词条——不再调参（保试玩共同基线）。
2. 组织 Batch 01：3-5 名首次玩家，不讲路线不解释词条；记录每关首次尝试词条、切换序列、失败原因、通关时间、L4 solution family、未预设合法序列。**【需用户决策：安排试玩人选】**（手册 reviews/playtest/demo-02-batch01-手册.md）。
3. 观察员加一个 Eureka 记录字段（玩家首次把旧 mechanic 用在新用途的时刻 + 有无「还能这样」言行）。

## 遗留
- GitHub Issue #1（W/S 反向）修复已随 v8 发布；回复/关闭需 PAT 具备 Issues 写权限或用户手动操作。
- itch 分发平台侧故障持续（对新构建部署环节），可玩链接以 GitHub Pages 为准。
- 主仓库有其他 demo 会话的未提交改动（demo-03 相关文件），本轮未触碰。

## 约束遵守
- 全程 headless/CLI 验证 + 公网 Pages curl，未打开 Godot 编辑器、未弹游戏窗口、未用本地前端测试。
- data/secrets.json 内容未写入任何报告或提交（miro-post-shots 由脚本自读密钥）。

## 追加（同日午）：L6 探索版轮
- 按用户「没活干就做更多机制关卡」指令，在不动 v10 基线前提下新增 **L6 抛接峡谷**（羽毛斜抛空中转向 → 浮空弹板二次点火 → 抛上基座；石头直线弹道对照失败），b 套件扩至 **11/11 全绿**。
- v11 探索版直链：https://tonyguan530.github.io/taptap2026/builds/demo-02-3d-v11/index.html （hub 槽未切，Batch 01 仍钉 v10）。
- 三个连带修复：换关球泄漏（v10 亦带，v11 修）、弹簧点火改几何查询（body_exited 不可靠）、触发带加厚防帧运气漏接。
- 新坑：硬杀 Godot 损坏 .godot 缓存 → 初始化 100% CPU 死循环；超时杀壳泄漏引擎子进程。

## 追加（同日下午）：L7 探索版轮
- 新增 **L7 破窗密室**：弹簧冲天→顶点切石头（复用 L2/L3 已教时机）→高速坠落砸穿密室整缝脆板天窗入室。判据干净：石头坠落 15+ m/s 破阈 14；皮球不切 12.2 破不了；羽毛更不行。首个侧面破窗方案因切石时机窗口仅 0.15s（对玩家过苛）被推翻，天窗方案时机=已教动作、容错大。
- 机制扩展：每关脆板阈值可覆盖（fragile.speed），全局默认 11 不变。
- b 套件扩至 **13/13 全绿**；v12 直链：https://tonyguan530.github.io/taptap2026/builds/demo-02-3d-v12/index.html （hub 槽未切，Batch 01 仍钉 v10）。

## 追加（同日深夜）：L8 探索版轮
- 新增 **L8 桥上桥下**：同一脆板双语义——路线A 羽毛全程 W 轻落桥面滚过桥尾（broken=false，require_break=false 不强制砸）；路线B 皮球不切词条全弧砸断脆桥坠谷底（broken=true）。双路线同 GOAL，反向教学 L2 的「轻过勿砸」。
- 机制扩展：脆板 require_break 过关门按关关闭（L2/L7 默认 true 不变）。
- b 套件扩至 **15/15 全绿**；v13 直链：https://tonyguan530.github.io/taptap2026/builds/demo-02-3d-v13/index.html （hub 槽未切，Batch 01 仍钉 v10）。
- 工程坑新增：批跑 15 连发后必现启动停振（清僵尸+删 .godot 即愈）；yaw=-PI/2 下 p_left 刹车推 Z 轴；node 正则跨行替换吞测试代码（已 git 恢复）。

## 追加（同日）：探索线素材补齐轮
- movie 驱动扩至八关连打；**八关视频重录**（35s/1050 帧，L5 与 L8 为 idle=true 零输入段）替换 reviews/videos/demo-02.mp4。
- 新增 L6/L7/L8 实机帧（reviews/shots/demo-02-3d-v13-L{6,7,8}.png），监督裁探索关时有完整视觉材料。
- L3 电影编排修正：30Hz 羽毛终端速过低飘不过降 → 松 W 切石头陡落入带（60Hz 套件判定不受影响）。
- 巡检：v10/v13/2D v7 全 200；反馈板无新数据。基线 PINNED 保护生效中。
