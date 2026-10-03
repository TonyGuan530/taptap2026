# 总督导遗留问题清单（各 demo 专属任务下轮消化）

> 督导每 10 分钟巡查时逐条核对，已解决的标记 [RESOLVED]；新发现追加到末尾对应 demo 节。督导自己不开发。

## demo-06 词条涂鸦创造
- [x] 【视频缺失】[RESOLVED 21:05 督导验收] demo-06.mp4 已录成（35s 三关通关剧本：L1 火球烧栅栏/L2 浮板两级跳/L3 浮板桥跨断层，Movie Writer+ffmpeg），并清理误提交的 48MB 帧序列（7e6967a）。
- [x] 【从未上 Miro 板】[RESOLVED 21:05 督导验收] miro-post-log.json 已出现 demo-06 条目，SHOTS 表补齐——7 个 build 上板覆盖首次 100%。
- [ ] 【L3 物理卡死】（老问题，任务提示已带）修复前 L3 不可上线。

## demo-01 灵感菇侦探
- [x] 【调度已修】[RESOLVED 2026-10-03 19:21 督导] cron 原为 `0 9 */1 * *`（每天仅 9 点一次），与 README 声明的每小时 :00/:30 不符，督导已 CronUpdate 修正为 `0,30 * * * *`。
- [x] 【GPT 对话已建】[RESOLVED 2026-10-03 19:38 督导] 督导已在 ChatGPT 建立专属对话并发出背景：https://chatgpt.com/c/6ac0e884-8b84-83ec-a462-ce4f684cc310 → 下轮评审直接在此续评，回复存 reviews/chatgpt-demo-01-full.md。
- [ ] 【NEEDS_WORK】旧评审要求真人试玩计时确认单局 2-3 分钟——需要时在汇报里提醒用户试玩。
- [x] 【提示词过时·注入取消】[RESOLVED 20:36 督导] demo-01 任务已自我进化为「每5分钟全局流水线」（健康自愈→停滞转向→subagent并行→发布QA），停滞四选一已纳入其转向阶梯并写入 README（6b0e5ad）——注入作废，督导适配新拓扑；灵感菇侦探的迭代改由流水线反馈跟进承担。
- [x] 【GPT full 缺失·归属流水线】[RESOLVED 21:27 督导] 督导亲自在 demo-01 专属对话发 v3 版本说明并存档 reviews/chatgpt-demo-01-full.md。**结论 ITERATE（明显接近 KEEP，差真人验证）**：①第一案加交叉推理点（重写2-3条证词）②允许 3/5 线索随时指认 ③Case02 极小 vertical slice；禁止再因时长加线索。→ 建议交流水线/任务下轮落实①②。

## demo-03 岩浆降温的小人国度
- [x] 【GPT 对话已建】[RESOLVED 2026-10-03 19:38 督导] https://chatgpt.com/c/6ac0e8c8-f34c-83ec-9c30-1cca9503c042 → 下轮（19:40 起）评审在此续评，回复存 reviews/chatgpt-demo-03-full.md。

## demo-04 SOUP 2.0 DNA 融合逃生
- [x] 【GPT 对话已建】[RESOLVED 2026-10-03 19:38 督导] https://chatgpt.com/c/6ac0e8ee-ce2c-83ec-b46c-bf1da4ee74f5 → 首轮 GPT 已预警「能力-障碍一一对应=脚本化谜题，涌现不足」，下轮把该意见纳入扩展（DNA 组合效果正是解法），回复存 reviews/chatgpt-demo-04-full.md。

## 全局
- [ ] 【部署核验 21:50·用户问询】**GitHub Pages 5/6 最新版在线**（demo-01 v3 / 02 v5 / 03 v6 / 05 v5 / 06 v8 play+build 全 200）；**demo-04 例外**：demos.json 已指向 v7 但 builds/demo-04-v7/ 未推送（Pages 404 持续 40 分钟，22:44 复查仍缺；其会话在产 dino 绿幕素材=活跃）→ **检查点 23:15**：22:45 轮收尾仍未见 v7 推送 → 注入【督导指令】要求 commit+push v7 构建目录。demo-04 现可玩 v6（builds/demo-04-v6/）。**itch 6/6 QA FAIL**（21:50 全量复测确认）——所有 demo 在 itch 均不可玩，Pages 为唯一可玩渠道；【需用户决策】A/B 仍待拍板（建议维持 A）。
- [x] 【WATCH·demo-04 疑似滞留】[RESOLVED 20:18 督导] 虚惊一场+修复生效：其首轮是 1 小时马拉松（19:19-20:15），20:15 督导 CronUpdate 后立即派发并交付 **v2（3关+DNA组合+碎片评级，headless 三用例 PASS，e6eb7cd）**，调度已重锚（runCount 2，下次 20:45）。停滞恢复四选一预案已注入其指令，下轮按 ChatGPT 评审结论选向。遗留：chatgpt-demo-04-full.md 因 OpenAI 429 未存档，下轮补。[RESOLVED 20:46 督导] full 文件已存档 ✓，v3 复评 KEEP 已入池。
- [ ] 【WATCH·demo-06 指令验收】[20:15] 已向 demo-06 任务注入督导指令（视频+上板=最高优先级）。第 3 轮 20:25 触发后验收：reviews/videos/demo-06.mp4 与 miro-post-log.json 的 demo-06 条目。
- [ ] 【需用户决策·itch CDN 持续故障】19:36（QA FAIL×4）、19:41（重推节流中仍 FAIL）、19:50（demo-02 v3 放弃 itch 走 GitHub Pages 兜底）——三次连续观察确认故障持续 25 分钟以上，非 CDN 传播延迟。当前各任务按既有预案自愈（Pages 兜底 + LitePipeline 重推），未阻塞发布。**请用户决策**：A. 维持现状（Pages 兜底，itch 恢复后自动回归）；B. 正式切 GitHub Pages 为主发布渠道（需改 push-itch/publish-qa/LitePipeline 业务工具，督导不代改）。未决策前督导维持 A 现状。
- [x] 【排队观察】[RESOLVED 19:55 督导] demo-01/02/05 的「过点未触发」实为长轮次合并排队：demo-01 第11轮已完成并推送（868cc47 三案件版），demo-02 首轮已产出 v3 并推送（c55430b），demo-03/04/05 首轮仍在跑且有持续文件活动。判定规则已补充：派发计数需用工作区活动佐证，有活动=长轮次进行中，不判卡死。
- [ ] 【git 未提交】19:25 时 12 个改动 + 2 个未跟踪（含 demo-01/03/06 的 gd 与测试文件——各任务开发轮正在进行，属正常中间态）→ 各 demo 任务收尾时顺带提交；若连续 3 轮未动，督导再代提交。
- [ ] 【评论池为空】data/db.json 尚不存在 = 7 个 demo 零玩家评论。评论驱动环节暂无输入，属正常冷启动，无需行动。
- [ ] 【WATCH·demo-07 留档 CI】[22:59] demo-07 会话遵照决策 #12 跑「v3 源码留档（不上线）」CI（run 37131617747 in_progress）。⚠️ 该 workflow 名为「导出并发布(Pages+itch.io)」——若完成后 demo-07 重新出现在 builds.json/Pages，督导立即 revert 并注入【督导指令】禁止再发布 demo-07。下轮巡查核验。
- [x] 【用户指令·demo-07 下架】[22:59 已执行并验证] demos.json 移除 slot ✓、builds/demo-07* 删除 ✓、线上 builds.json 已无 demo-07（前5=demo-05v5/02v5/03v6/06v8/06v7）✓、live demos.json 0 处 demo-07 ✓。hub=1-6。
- [ ] 【注入待执行·demo-04 v7 强推】[23:05] 检查点到达：v7 构建（builds/demo-04-v7/）仍未入库，Pages 指针 404 已 50 分钟，demos.json 指向 v7。**下轮巡查第一动作**：CronUpdate automation-d3f50080-356e-4958-a2f6-edfc516e67a4，在其 21:20 版提示词最前面注入——「【督导指令 2026-10-03 23:15·v7 部署补推】builds/demo-04-v7/ 与 dino 绿幕素材仍未入库，Pages 指针 404。本轮收尾必须：git add builds/demo-04-v7/ reviews/art/dino* 与 demo-04 相关文件，git push origin main 使 Pages v7 生效；若上轮已推则跳过。」注：本轮督导因工具循环未能完成注入（已自查），勿再拖延。
- [x] 【部署核验·demo-04 v7 404】[RESOLVED 23:10 督导] 督导代推送 builds/demo-04-v7/ 入库（63767d1），最新 CI 部署后 Pages 200 ✓；demo-04 会话冻结守望轮2 已核验并向督导上报「builds/ 入库不会自动上线」的镜像缺口——已由督导代发布闭环。
- [x] 【LitePipeline 停转核查】[RESOLVED 23:07 督导] 根因=计划任务被禁用（模式:已禁用，19:41 后停摆）；已 schtasks enable + 手动触发一次。itch 自愈恢复运转，持续观察 pck/wasm 恢复。demo-06 的请核查请求已闭环。
- [ ] 【WATCH·itch pck/wasm】LitePipeline 恢复后观察 1-2 轮是否全量匹配；匹配则【需用户决策】A/B 自动收敛为 A。
- [ ] 【WATCH·demo-08/09】Miro 新增两条想法（纸飞机模拟器/赛车模拟器）已收录 backlog——待流水线找活认领或用户指示排期。
- [x] 【用户指令·Windows 计划任务停用】[00:49 执行] TapTap-LitePipeline 与 TapTap-KeepZCodeAlive 两个 Windows 计划任务已按用户指令禁用（停一下，不要自动的 Windows 控制命令）。 itch 自愈循环暂停——占位分发问题完全等 itch 服务端恢复，Pages 渠道不受影响。恢复方式：schtasks /change /tn <任务名> /enable。
