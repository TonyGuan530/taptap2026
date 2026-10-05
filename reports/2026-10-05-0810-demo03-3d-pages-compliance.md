# demo-03 3D 线 · Pages 清理令合规执行 + 全量回归（2026-10-05 08:10 轮）

## 督导 Pages 清理令（reviews/supervisor-directive-2026-10-04-pages-cleanup.md，三轮）合规情况
1. 清点 origin/main builds/：**demo-03 3D 线现仅存 demo-03-3d-v12 一个目录**——符合第二轮令"每线保留最新 1 版"（v4~v11 已由督导代执行清理，git 历史可恢复）。
2. **依 09:52 规则修正第 1 条，为 v12 加 `builds/demo-03-3d-v12/PINNED.md`**：声明其为真人盲测基线（手册 reports/2026-10-05-0310-blindtest-kit-3d.md 的唯一链接目标），申请无条件保留；若未来换盲测入口，先改手册再解钉。已上线（Pages 200，main @ c39c5f3）。
3. 防复发条款（>900M 自动清、800MB 红线）知悉；本线后续发版将自带"发新版即提醒清最旧版"节奏（verify-release 已盯本地构建，线上体量由流水线巡检）。

## 全量回归（本轮质量保障）
- 模拟 **94/0** · 输入 **46/0** · 场景 **12/0**（headless）。
- `tools/verify-release.mjs demo-03-3d-v12`：**RELEASE OK 全链一致**（demos.json / Pages 三件套 / itch WARN 共享轮转 / 本地构建 / git 干净已推 / 视频新鲜度）。

## 状态
v12 冻结不变；PINNED 后盲测入口具备防误删保护。等待：真人盲测结果、督导 v4~v12 回看、（可选）Miro token 与可占用鼠标时段。

## 提交
- main（plumbing）：PINNED.md（c39c5f3）；worktree 分支：本报告。
