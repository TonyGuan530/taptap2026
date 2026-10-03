# demo-02 · Playtest Batch 01 执行手册（3-5 人无提示试玩）

- 版本基线：**demo-02-v5**（instrumentation freeze——参数/几何/提示已冻结，测试期间不改）
- 试玩链接：https://tonyguan530.github.io/taptap2026/play.html?id=demo-02 （或 itch sxguan.itch.io/taptap2026，密码 taptap）
- 组织者：每人一台电脑/一个浏览器标签，**不给任何玩法提示**

## 开场白（照读）

> 这是一个物理解谜小游戏 demo，一共 4 关。右侧三个按钮可以给小球换「词条」，物理行为会跟着变。目标：把球送进金色的 GOAL 区。卡住了可以点右上角「重置」。开始吧，你想怎么玩都行。

**不说**：路线、参考解法、阈值数字、哪个词条好使。

## 观察守则（只记录，不提问，不提示）

- 玩家卡住 >30 秒开始挣扎时才允许第一次提示：「试试右上角重置」；仍卡住记录一次「需提示」
- 玩家通关后**不说话**，观察是否主动按「从头再来」/「下一关」（replay_voluntarily）
- 不问「觉得好玩吗」；只在结束后问一句「你刚才是怎么想到这么过的？」并原话记录

## 每人一张记录表（游戏通关行会显示「路线#N: …」，直接抄录）

| 字段 | 记录 |
| --- | --- |
| tester_id | P01…P05 |
| run_index | 第几次玩本关（抄游戏路线行「路线#N」） |
| L4_first_attempt_time | 首次通关 L4 用时（抄通关行秒数） |
| switch_chain + zone | 抄通关行「路线: 石头@6.7s[high_window]→…」 |
| reset_count | 抄通关行「重置N」+ 目测手动重置次数 |
| spring_used | 是否借弹簧（通关行含「借弹簧」？） |
| fragile_hit_count / speeds | 提示行撞板次数与速度（debug 数字版） |
| route_observed | A（右敞口直漂）/ B（砸穿脆板）/ New（其他，描述）/ Failed |
| unexpected_behavior | 一句话：玩家做过的最意外尝试（哪怕失败） |
| replay_voluntarily | 通关后是否主动再玩（强信号） |

## Batch 判定（数据回收后交回流水线做 Gate 报告）

- ≥2 人自发走出 A/B 之外的路线 → 涌现强信号
- 多数人从未在空中切词条 → 切换可发现性问题，ITERATE
- 通关者主动重玩 → 「好玩」的最强证据
- 普遍卡 L1-L2 → 可发现性/引导问题（冻结期只记不改，数据齐后统一决策）
