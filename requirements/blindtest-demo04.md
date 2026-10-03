# demo-04 盲测执行手册（3-5 人 · GPT P2 验证）

## 目的
验证 GPT 设定的 Gate：**玩家在没有教程的情况下，主动把新发现的 DNA 组合复用到旧环境或可选路线**（scripted discovery → player-driven experimentation）。

## 准备
- 试玩链接：https://sxguan.itch.io/taptap2026（密码 taptap；若 itch CDN 故障用 GitHub Pages 最新版）
- 版本：demo-04-v6 及以上（含实验房遥测 v2）
- 每位玩家开始前：进入实验房按 **G** 切换到该玩家的匿名编号（P01→P02→…）；同一玩家多次尝试**不要**重复按 G（run_index 自动区分次数）
- 不做任何机制讲解，只说：「横版游戏，跑到右边逃生舱。路上会遇到外星生物，可以按 E 融合。」

## 样本类型（GPT v11 复评要求：两类样本对照）
- **campaign-first（≥3 人）**：正常从 L1→L5 通关后进实验房——测「学习后会不会主动迁移和重组」
- **lab-first（1-2 人）**：坐下后由操作员按 **K** 直接送入实验房——测「玩家是否会自己形成 DNA 可组合的假设」；**不告知玩家为什么被送进去，不解释组合机制**
- 玩家问「这里怎么过」「DNA 能组合吗」→ 统一回答「按你自己的理解继续试」（零提示规则）
- 首玩数据单独保留（tester_id 区分玩家，run_index 区分同一人多次）

## 流程（每人 10-15 分钟）
1. campaign-first：自由通关 5 个关卡（不提示组合、不提示捷径）后进实验房；lab-first：K 送入实验房直接开始
2. 实验房内自由玩 3-5 分钟
3. 测试者全程安静观察，只在卡死 2 分钟以上时提示一次「试试 R 或 B」
4. 结束后按 **T** 导出遥测（浏览器会下载 demo04_lab.json），按玩家编号存档

## 人工观察表（每人一份，测试者填写，GPT 要求的 4 项）
| # | 观察项 | 是/否 | 备注（时刻/触发点） |
| --- | --- | --- | --- |
| 1 | 第一次看到 L3 高台/实验房高台时，**主动尝试**抵达 | | |
| 2 | 发现超级弹跳后，**主动回头**重新测试之前的地形/高台 | | |
| 3 | 在**没有提示**的情况下尝试其他 DNA 配对 | | |
| 3b | 玩家是否**因看到裂纹墙微光脉动**才首次尝试撞墙（提示强度观测） | | |
| 4 | 玩家第一次说出类似「那这两个是不是也能组合？」的**原话** | | （第 4 条最重要，遥测无法判断） |

## 遥测数据（自动采集，勿干预）
- 文件：浏览器下载的 demo04_lab.json（或 user://demo04_lab_log.json）
- 事件信封：session_id / tester_id / run_index / elapsed_ms / event_type / player_x / player_y / facing / owned_dna
- 事件类型：session_start(含 mode/level), dna_fused(含 order), combo_discovered, jump, zone_enter(spawn/dna_cluster/high_platform/gap/far_side), platform_attempt/platform_reached, gap_attempt/gap_crossed, **wall_broken / break_attempt(v9 新增：L4/L5 碎墙行为，区分「有碎岩击穿」与「没碎岩硬撞」)**, session_end
- 禁止采集：每帧输入/鼠标轨迹/每帧位置/物理状态/FPS（GPT 明确排除）

## 额外观察（GPT v8 复评要求）
- HUD 密度：玩家是否频繁停下来读顶部文本、是否漏看 DNA 状态
- L4 双解选择：走碎岩直穿还是组合跳越（遥测 wall_broken/break_attempt 可佐证）

## 交付
- 每人：遥测 JSON + 观察表照片
- 分析：发给 ChatGPT 专属对话（reviews/chatgpt-conversations.json → demo-04），重点三类行为链——主动探索、组合发现后的重新解释、未被提示的配对假设
