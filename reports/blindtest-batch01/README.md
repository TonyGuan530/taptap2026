# Batch 01 真人盲测数据归档（2026-10-04 起）

> 督导建：真人试玩数据统一放本目录，督导巡查自动识别并批示对应 demo 任务消化。

## 文件命名约定
- `demo-NN-测试者昵称.md`（文字记录）或 `demo-NN-batch.xlsx/csv`（表格）
- 每条记录建议含：测试者编号、玩的版本号、用时、是否通关、卡点、一句话体验

## 各 demo 判读模板位置
- demo-04：requirements/blindtest-demo04.md（两类样本协议/观察项 3b）
- demo-05：行为学四指标（真人 5 局 Gate 模板）
- demo-06：reviews/videos 同目录手册 + blindtest_summary.mjs 汇总器
- demo-10：四数据（anomaly 敢不敢留/圆回自然度/type 分流/未发现比例）
- demo-11：解法家族五族 + Room5 首玩可发现性

## 遥测（自动采集，无需手填）
试玩 Pages 版即自动上报；汇总命令：node tools/blindtest_summary.mjs（demo-06 已交付）
