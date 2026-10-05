# demo-03 3D 线 · 性能入账 + 状态交接文档（2026-10-05 06:10 轮）

## 一、性能实测（指南阶段 C/D 验收项："记录机器、分辨率、帧率和包体积"）
- 工具：`tools/perf-fps.mjs`（Edge headless 实载 v12 构建，rAF 采样 15s×两模式）。数据：`reports/perf-fps-v12.json`。
- **结果：classic 179.5 fps / storm 178.9 fps，最差帧 7ms**——远超 60fps 预算；两模式无差异（雨层/细雨/描边开销可忽略）。
- 环境：RTX 2070（D3D11 ANGLE，headless Edge 走真 GPU）、1280×720、CPU 见 JSON。注意：headless 数据作为**同机可比基线**，弱核显机器需盲测时顺带体感确认（游戏逻辑 60s 短局+几何量小，风险低）。
- 包体积（build.json/导出记录）：pck 7.5MB + wasm 39.5MB + js/html ≈ **48MB/版**。

## 二、状态交接（给未来会话/协作者）

### 当前版本
- **demo-03-3d-v12**（玩法冻结基线）：itch html 通道 √ + GitHub Pages 200 + demos.json demo-03 → v12。
- 分支 `demo03-3d`（worktree D:\GIT\taptap2026-demo03-3d），最新提交见 git log；main 保持 2D 线（demo-03-v14 为 2D 回归对照，不要动）。

### 玩法基线（v4~v11 增量，规则面）
- 原版规则全保留；新增：**灭火指挥**（F，25水→8s 全队降温+1.5/s，冷却 20s，不吃酸雨乘区）、**蓄水池**（60水，4.5/s，酸雨完全失效）、**第 2 章寒夜守卫**（hard：起始 50/三场 6s 酸雨/村民 30-50s）、**风暴热浪**（38~43s 升温×1.5）、风暴紫黑夜空+环境细雨（v5）、结算遥测面板+复制（v7）。

### 常用命令（全部 headless，禁止弹窗——见 reviews/STANDING-CONSTRAINTS.md）
```bash
G=/d/GIT/taptap2026/tools/godot/Godot_v4.7.2-stable_win64_console.exe
# 测试（94/39/12 断言，非零=失败）
"$G" --headless --path game -s res://tests/test_demo03_3d.gd
"$G" --headless --path game -s res://tests/test_demo03_3d_input.gd
"$G" --headless --path game -s res://tests/test_demo03_3d_scene.gd
"$G" --headless --path game -s res://tests/sweep_balance_v12.gd   # 平衡扫描（工具）
# 导出（先跑 tools/subset-font.mjs 若改过 UI 文案）
"$G" --headless --path game --export-release "Web" "D:/GIT/taptap2026-demo03-3d/builds/<版本>/index.html"
# 发布三件套
bash tools/push-itch.sh <版本>
node tools/browser-smoke.mjs <构建URL> reviews/shots/browser-smoke-<版>
node tools/hub-smoke.mjs https://tonyguan530.github.io/taptap2026/ <版本> reviews/shots/hub-smoke-<版>
# Pages/demos.json：git plumbing（临时索引+commit-tree）推 main，勿动主检出
# 视频：node tools/record-video.mjs <构建URL> reviews/videos + ffmpeg 转 mp4
```

### 待决项（等外部输入，非代码问题）
1. **真人盲测**：手册 `reports/2026-10-05-0310-blindtest-kit-3d.md`（入口 v12），唯一 KEEP 通道。
2. **督导回看**：v4~v12 九份备案草案在 `reviews/chatgpt-demo-03-3d-v*-pending.md`（发送需浏览器占鼠标，被禁令挡住）。
3. **平衡调参**：扫描发现"会玩局终局零压力"（reports/balance-sweep-v12.md 发现 2）——等盲测确认后再动，动了必须重跑全部用例+2D 对照。
4. **Miro 回贴**：tools/miro-post-shots.mjs 需 token（/key 页）。

### 已知坑（详见 reviews/STANDING-CONSTRAINTS.md）
- 改 UI 文案必须重跑 subset-font；发布必须跑双冒烟；/api/* 404 是静态托管预期；不弹窗、不占鼠标。

## 补录（2026-10-05 07:40 轮）：SwiftShader 软件渲染下限
- `PERF_SW=1 node tools/perf-fps.mjs …` 强制 SwiftShader（纯 CPU 渲染，数据 reports/perf-fps-v12-swiftshader.json）：
  **classic 42.6 fps / storm 36.7 fps，最差帧 34ms**。
- 结论：即使完全无 GPU 加速也可玩（>30fps）；真核显（Intel/AMD iGPU）介于两者与独显之间。盲测可告知"任意现代机器可玩"，无需优化。
- 工具：perf-fps.mjs 支持 PERF_SW=1 开关。
