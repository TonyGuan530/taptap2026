# demo-08 3D 迁移 · 第 7 轮（发布 demo-08-3d-v1：Pages 兜底上线，itch 平台故障跳过）

日期：2026-10-04。执行：demo-08 定时任务 automation-1d162838。

## 发布：demo-08-3d-v1 已上线（GitHub Pages）

- **试玩入口**：https://tonyguan530.github.io/taptap2026/play.html?id=demo-08-3d （demos.json slot `demo-08-3d`，status done）
- 内容：五关完整（L4 双门横侧位）+ A/D 横移 + 门横向宽度 + 结算轨迹复盘小图 + 3d-shared 基座 comic 风格。
- **验证（全 CLI，无弹窗）**：
  - 回归门：headless 55+13+11+11 + 屏幕外窗口回归 19+28+8（wintest 增加"立即最小化"+`--position -8000,-8000`，桌面不可见不抢鼠标——方案与 DEMO9 会话一致）。
  - Pages 传播：builds/demo-08-3d-v1/index.html md5 `18fb158f…` 与本地一致；play.html 200；demos.json 200 含 slot；index.pck 支持 206 分段（wasm 流式可用）。
- **itch：跳过**。publish-qa 两次 FAIL，远程 md5=0822277b（占位页）——10-03 起 itch 平台 CDN 故障延续（历史报告多轮记录，非本项目可控）。按既定流程改发 GitHub Pages 兜底并记录；itch 恢复后可补推 push-itch.ps1 -Version demo-08-3d-v1。
- 主仓库提交 a18941b（builds/demo-08-3d-v1 46MB + demos.json slot）。**如实说明**：该提交捎带了并行 demo-04 会话已暂存的 builds/demo-04-v11→demo-04-3d-v1 改名（其有意变更，提前上线，无破坏；已在其队列可见）。

## 阶段 C 判定：完成

五关完整迁入 ✅ / 门横向宽度 ✅ / 地形碰撞 ✅ / 低面数模型=基座套件 ComicObject+GLB（自研纸飞机 GLB 留可选打磨）✅ / 结算轨迹复盘小图 ✅。窗口会话清单（发布后观察项，不阻塞）：小图绘制效果、L4 门横位视觉、真人折法探索记录（D 阶段）。

## 无弹窗纪律落地记录

wintest_demo08_3d_{scene,l2,b1_input}.gd 起始处 `DisplayServer.window_set_mode(MAIN_WINDOW_ID, WINDOW_MODE_MINIMIZED)`；运行命令统一 `--position -8000,-8000`。实测：三套 19+28+8 全绿（修复 window_set_minimize→window_set_mode 的 API 名称）。

## 下轮

- 阶段 D 剩余：真人折法探索记录（需真人，挂观察）；Pages 上公网冒烟（curl 已做，浏览器级 iframe 体验=窗口会话/用户自测）。
- fallback 准备：指南四阶段仅剩"真人验证+可选打磨"，若连续无新可执行项，按用户指令转入**更多机制关卡**（LEVELS 扩展，headless 双用例）。
- itch 恢复监控交给 pipeline-lite（既有职责）。
