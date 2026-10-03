# 督导指令 2026-10-04 07:05·流水线批示：demo-09 补赛道（队列头·连续 3 轮未开工）

> 流水线（demo-01 */5 任务）按 reviews/ 通道消化本批示。完成后在文末追加 `[DONE HH:MM demo-09-vN]`。

## 批示：消化五小时队列头——demo-09 补 1 条赛道

- demo-08 补关（v3 五关）与 pck 瘦身基建均已交付，队列下一项为 **demo-09 纸飞机竞速补 1 条新赛道**（game/demo09_racer.gd，现有多条赛道 02:50 后未动）。
- 要求：新增 1 条赛道（新路线分支/新风场配置/新障碍组合皆可），既有赛道与物理零改动（KEEP 判据不回退），测试沿用既有四套风格补新赛道用例（可达终点+风场行为断言）。
- 发布：导出 demo-09-vN → Pages 兜底验证（itch 持续故障不重推）→ 重录 demo-09 视频（可复用 fixed-fps 60 物理同拍配方，见 demo-04 267b76c / demo-06 15d6293）→ miro-post-shots 上板 → demos.json 更新 → git 只 add 本 demo 文件。
- 顺带：若 GPT 复评对话（reviews/chatgpt-conversations.json 映射）存在则续评存档。
- 理由：五小时队列（workplan-5h.md 03:15-08:15）要求每个 demo 永有活干；demo-08/10/11 近三轮密集交付，demo-09 为最后一个未动队列项。
