# 流水线报告 · demo-06 盲测数据汇总工具（关键路径解锁物 2）

- 时间：2026-10-04 09:00（07:25 场次）
- 结论：`tools/blindtest_summary.mjs` 交付——把游戏「📦数据」导出的 telemetry JSON 自动汇总成 ChatGPT Gate 判定所需的「每人一行」摘要。合成样本自测通过。

## 功能
- 输入：组织者把每人「📦数据」复制的 JSON 存入 `reviews/blindtest/`（P01.json…），运行 `node tools/blindtest_summary.mjs reviews/blindtest --markdown`。
- 每人一行（ChatGPT 判定格式）：P01 | 通关L3?Y | 首解=圆球+Heavy→长板+Float×N | 用时 | 组合尝试 N | 用环境物 Y/N | 首试Heavy=Ns | 试Sticky=Y/N。
- 组合明细 + 迁移轨迹（L3 vs L4/L5/L6 分开——落实评审「L3 测发现、后关测迁移」的分开统计）。
- 跨会话合并：同 pid 多次运行按 sid 自动分段。

## 自测
- 合成样本（L3 通关局：Heavy 首试 → Float 板×3 → 坠落重试 → 182s 通关）：输出全部字段正确（用环境物 Y/N 检测初版读错事件类型已修正为 contact 事件）。
- 游戏代码零改动（冻结维持）；v13 在线状态不变。

## 状态
demo-06 盲测就绪度：游戏 ✓ telemetry ✓ 手册 ✓ 汇总工具 ✓ —— **剩余唯一依赖 = 组织者排期真人**。itch 分发故障持续（督导盯守）。
