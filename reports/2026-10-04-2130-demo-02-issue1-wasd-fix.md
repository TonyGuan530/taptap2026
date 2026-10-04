# 流水线报告 · demo-02 首条真人反馈消化（GitHub Issue #1：W/S 反向，已修复上线）

- 时间：2026-10-04 21:30
- 触发：用户指令「查看github反馈」——**这是流水线收到的第一条真实玩家反馈**，反馈回路（GitHub Issue 表单 → 流水线消化）首次端到端走通

## 反馈内容（Issue #1，TonyGuan530，2026-10-04）

- 试玩对象：demo-02（3D 灰模预览版，WASD 仅存在于 3D 版）
- 结果：没通关（卡住），玩了约 1 分钟
- 反馈：**「WASD 反掉了」**（重复三次，玩家认定这是最大问题）

## 根因与修复

- **根因确认**：`Input.get_axis("p_fwd", "p_back")` 参数顺序写反——get_axis(负向, 正向)，把 W（前进）当成了负向 → W/S 前后反向（A/D 左右正常）。玩家反馈准确。
- **修复**：参数顺序对调（demo02_3d.gd 移动输入行），一行修复
- **回归用例**：test_demo02_3d_a.gd 新增 ⑧a/⑧b WASD 方向断言（yaw=0 时 W 产生 -Z 速度、S 产生 +Z 速度）
- **验证**：headless 11 断言全 PASS（L1-L4 机制 9 项 + WASD 2 项），exit=0

## 发布（做完即传）

- demo-02-3d-v2 已导出并上 **Pages 验证通过**（build.json = demo-02-3d-v2）：https://tonyguan530.github.io/taptap2026/play.html?id=demo-02-3d
- hub 槽 demo-02-3d buildId 已更新
- itch：本次未推（分发环节平台故障持续，Pages 为准）

## 遗留 / 需用户操作

1. **Issue #1 回复与关闭需手动**：流水线 PAT 无 Issues 写权限（403）。回复文案已备：「根因是 get_axis 参数顺序写反导致 W/S 反向，已修复上线 demo-02-3d-v2 + WASD 回归用例已加」。可给 token 加 Issues 写权限或手动关闭
2. 3D 工作树导出脚本 export-web-3d.ps1 的中文注释在 PS5.1（无 BOM）下解析失败——注释改 ASCII 待下轮修正
3. Batch 01 试玩人选安排（持续有效）

## 过程发现

- 反馈闭环首次走通：GitHub Issue 表单（demo-02 页面反馈块）→ API 读取 → 根因修复 → headless 回归 → Pages 上线，全程约 1 小时
- 反馈定位效率高：玩家一句话直接指向可复现的输入 bug
