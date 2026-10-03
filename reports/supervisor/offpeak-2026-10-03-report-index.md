# 闲时找活报告 · 2026-10-03 20:43-20:46 · 报告索引整理

## 做了什么
- 生成 **reports/INDEX.md**：18 份流水线/任务报告的完整索引（按日期分表 + 一句话主题），新报告由各任务收尾时自行追加。
- 未 commit：工作区有 demo-04 在途改动（`M game/demo04_soup.gd`）+ 未跟踪的 test_demo02_v4.gd、**reviews/videos/demo-06.mp4（demo-06 指令轮刚录好，验收在即）**——按硬性边界不碰 git。

## 发现
1. **backlog 状态标签过期**：requirements/backlog.md 的 demo-01 节（L19）与 demo-02 节（L100）仍标「状态：待开发」，但 public/demos.json 七个 slot 全部 done。属文档失真非代码问题。
2. demo-06.mp4 已出现（20:43 后），其 Miro 上板动作预计在其指令轮内完成——督导 20:55 验收点大概率能过。
3. demo-02 的 v4 测试文件（test_demo02_v4.gd）已出现在工作区，v4 轮（跳跃简化/L4 开放）在途。

## 建议
- backlog 两处「待开发」标签建议由各 demo 任务收尾时顺手改为 done 并补迭代记录（业务文件，闲时任务不抢写，避免与在途轮冲突）。
- INDEX.md 待工作区干净后由督导产物上传顺带入库即可，无需专门提交。

## 本次未动的区域（合规自查）
- 未碰 game/ 业务代码、未跑发布流水线、未建任何任务、未读 secrets.json。
