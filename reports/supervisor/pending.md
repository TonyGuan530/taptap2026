# 总督导遗留问题清单（各 demo 专属任务下轮消化）

> 督导每 10 分钟巡查时逐条核对，已解决的标记 [RESOLVED]；新发现追加到末尾对应 demo 节。督导自己不开发。

## demo-06 词条涂鸦创造
- [ ] 【视频缺失·第3次催办】reviews/videos/ 仍缺 demo-06.mp4（20:09 复查未补）→ 下一轮必须录制。
- [ ] 【从未上 Miro 板·第3次催办】reviews/miro-post-log.json 仍无 demo-06 条目（20:09 复查未补）→ 下轮跑 node tools/miro-post-shots.mjs 补 SHOTS 表 demo-06 行。
- [ ] 【L3 物理卡死】（老问题，任务提示已带）修复前 L3 不可上线。

## demo-01 灵感菇侦探
- [x] 【调度已修】[RESOLVED 2026-10-03 19:21 督导] cron 原为 `0 9 */1 * *`（每天仅 9 点一次），与 README 声明的每小时 :00/:30 不符，督导已 CronUpdate 修正为 `0,30 * * * *`。
- [x] 【GPT 对话已建】[RESOLVED 2026-10-03 19:38 督导] 督导已在 ChatGPT 建立专属对话并发出背景：https://chatgpt.com/c/6ac0e884-8b84-83ec-a462-ce4f684cc310 → 下轮评审直接在此续评，回复存 reviews/chatgpt-demo-01-full.md。
- [ ] 【NEEDS_WORK】旧评审要求真人试玩计时确认单局 2-3 分钟——需要时在汇报里提醒用户试玩。

## demo-03 岩浆降温的小人国度
- [x] 【GPT 对话已建】[RESOLVED 2026-10-03 19:38 督导] https://chatgpt.com/c/6ac0e8c8-f34c-83ec-9c30-1cca9503c042 → 下轮（19:40 起）评审在此续评，回复存 reviews/chatgpt-demo-03-full.md。

## demo-04 SOUP 2.0 DNA 融合逃生
- [x] 【GPT 对话已建】[RESOLVED 2026-10-03 19:38 督导] https://chatgpt.com/c/6ac0e8ee-ce2c-83ec-b46c-bf1da4ee74f5 → 首轮 GPT 已预警「能力-障碍一一对应=脚本化谜题，涌现不足」，下轮把该意见纳入扩展（DNA 组合效果正是解法），回复存 reviews/chatgpt-demo-04-full.md。

## 全局
- [x] 【WATCH·demo-04 疑似滞留】[RESOLVED 20:18 督导] 虚惊一场+修复生效：其首轮是 1 小时马拉松（19:19-20:15），20:15 督导 CronUpdate 后立即派发并交付 **v2（3关+DNA组合+碎片评级，headless 三用例 PASS，e6eb7cd）**，调度已重锚（runCount 2，下次 20:45）。停滞恢复四选一预案已注入其指令，下轮按 ChatGPT 评审结论选向。遗留：chatgpt-demo-04-full.md 因 OpenAI 429 未存档，下轮补。
- [ ] 【WATCH·demo-06 指令验收】[20:15] 已向 demo-06 任务注入督导指令（视频+上板=最高优先级）。第 3 轮 20:25 触发后验收：reviews/videos/demo-06.mp4 与 miro-post-log.json 的 demo-06 条目。
- [ ] 【需用户决策·itch CDN 持续故障】19:36（QA FAIL×4）、19:41（重推节流中仍 FAIL）、19:50（demo-02 v3 放弃 itch 走 GitHub Pages 兜底）——三次连续观察确认故障持续 25 分钟以上，非 CDN 传播延迟。当前各任务按既有预案自愈（Pages 兜底 + LitePipeline 重推），未阻塞发布。**请用户决策**：A. 维持现状（Pages 兜底，itch 恢复后自动回归）；B. 正式切 GitHub Pages 为主发布渠道（需改 push-itch/publish-qa/LitePipeline 业务工具，督导不代改）。未决策前督导维持 A 现状。
- [x] 【排队观察】[RESOLVED 19:55 督导] demo-01/02/05 的「过点未触发」实为长轮次合并排队：demo-01 第11轮已完成并推送（868cc47 三案件版），demo-02 首轮已产出 v3 并推送（c55430b），demo-03/04/05 首轮仍在跑且有持续文件活动。判定规则已补充：派发计数需用工作区活动佐证，有活动=长轮次进行中，不判卡死。
- [ ] 【git 未提交】19:25 时 12 个改动 + 2 个未跟踪（含 demo-01/03/06 的 gd 与测试文件——各任务开发轮正在进行，属正常中间态）→ 各 demo 任务收尾时顺带提交；若连续 3 轮未动，督导再代提交。
- [ ] 【评论池为空】data/db.json 尚不存在 = 7 个 demo 零玩家评论。评论驱动环节暂无输入，属正常冷启动，无需行动。
