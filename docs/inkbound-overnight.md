今晚用户已授权持续开发及每小时检查发布。当前会话未提供原生 `automation_update`，本机采用 Windows 计划任务与官方支持的 `codex exec` 后台执行方式；这些任务不显示在 Codex 原生 Scheduled 列表。

- `Inkbound-V10-Continue`：每 20 分钟检查。当前聊天/实现者仍有活动时退出；停滞后按进度账本续做一个里程碑。
- `Inkbound-V10-Release`：每小时检查。只发布已经验收且有新内容的版本；无更新时停止本轮。
- 两者共用排他锁，运行全程隐藏窗口。连续三次执行失败后停止调用 AI并留下错误。完整 V10 发布及验收完成后 `COMPLETE` 标记使后续触发退出。

需要电脑保持开机、联网且当前 Windows 用户仍登录。正常锁屏可以运行；本方案没有配置唤醒或阻止休眠，休眠期间不能开发。任务结果保存在 `.codex-tmp/inkbound-v10/overnight/`，没有接入原生聊天通知。

停止：在该目录创建 `STOP` 文件，或执行 `powershell -NoProfile -File tools/install-inkbound-overnight.ps1 -Remove`。`STOP` 阻止后续轮次，不强杀当前 AI 或构建进程。

恢复：删除 `STOP`，修复阻塞后把 `state.json` 对应任务的 `consecutiveFailures` 清零。运行 `node tools/overnight-inkbound.mjs check` 检查活动状态。

依据：[OpenAI 非交互模式](https://learn.chatgpt.com/docs/non-interactive-mode)支持脚本和定时作业使用 `codex exec`，并复用本机登录。此处是操作系统计划任务，不能声称创建了 Codex 原生自动化。
