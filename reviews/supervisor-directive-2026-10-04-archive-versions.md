# 督导指令 2026-10-04 12:20·历史版本归档令（用户指令：直接删除或归档）

> 用户原话：「github和itch里面的历史版本功能属实鸡肋 直接删除或者归档」。本令将 Pages 清理规则从「每 demo 留 2 版」收紧为「**每 demo 只留最新 1 版**」。

## 1. GitHub Pages（builds/）——流水线执行

- 全库 builds/ 只保留每个 demo 的**最新 1 版**（删除上一轮清理留下的次新版：demo-02-v6、demo-03-v13、demo-04-v11、demo-05-v21、demo-06-v12、demo-08-v2、demo-09-v1、demo-10-v3、demo-11-v2；demo-01-v3/07 等单版不动）。
- 归档语义：git 历史天然归档（`git log -- builds/<dir>` + `git checkout <commit> -- builds/<dir>` 可随时恢复），不另建归档目录。
- 预期 909MB → 约 450MB。完成后追加 `[DONE HH:MM 剩余总量]`。
- **demo-05 特例**：itch 频道当前推的是 v20，Pages 侧留 v22（最新）——若分发恢复后发现 itch 需要与 Pages 同版，重推 v22 即可。

## 2. itch 版本历史——技术限制说明

- butler 无删除历史 build 的命令；itch 官方 API 不开放删除端点，仅开发者 dashboard 手动可删。
- 对玩家而言 itch 页面**永远只显示最新分发版本**，历史版本本就不可见（鸡肋感来自 dashboard 侧，不影响玩家）。
- 处置：维持现状（dashboard 手动清理由用户决定）；分发恢复后如需同版刷新，重推该 demo 最新版即可。

## 3. 反馈看板（同步交付）

- `.github/ISSUE_TEMPLATE/feedback.yml` 已上线：Jira 式表单（demo 下拉/版本/结果/时长/卡点/星级/自由反馈/设备），提交自动打 `feedback` 标签。
- Pages hub 页脚已加「📝 试玩反馈」入口（issues/new?template=feedback.yml 直达）。
- **督导巡查流程新增**：每轮 `gh issue list --label feedback` 拉取新反馈 → 归档 reports/blindtest-batch01/ → 批示对应 demo 任务消化。
