# 督导指令 2026-10-04 11:55·紧急：Pages 超限全库清理（最高优先级）

> 事件：GitHub Pages 站点 builds/ 总量 4.1GB，超 1GB 软限 → **部署失败**（实证：demo-03 v13 Pages 404）。Pages 是当前唯一在线试玩通道（itch CDN 分发仍卡死），必须立即恢复。
> demo-03 已示范：删除本 demo 旧版构建 v1~v11、保留 v12/v13，释放 600MB（9604869）。

## 批示：流水线（demo-01 */5）牵头，各 demo 任务配合执行

1. **全库构建清理**：builds/ 下每个 demo 目录只保留**最新 2 版**（如 demo-05 只留 v19/v20，demo-06 只留 v13/v14），删除更早版本目录。
   - 删除前确认：最新版 Pages 可达（curl 200）+ git 历史完整（旧版可随时恢复：`git checkout <旧commit> -- builds/<dir>`）。
   - 预期释放约 2.5GB+，把站点压回 1GB 以内。
2. **清理后验证**：`git push` 触发 CI → curl 各 demo 最新版 index.html 全部 200 + builds.json 更新（重点验证 demo-03 v13 从 404 转 200）。
3. **防复发**：此后各 demo 每发布 2 个新版本即清理 1 个最旧版（写入各自流程），站点总量红线 800MB。
4. demo-09/v1 等长期未动版本同样适用保留最新 2 版规则。
5. 完成后在本文件末尾追加 `[DONE HH:MM 剩余总量]`。

## 依据

- Pages 部署失败影响全部 demo 的线上可达性，属全项目级故障；旧版构建在 git 历史与 itch butler 中均有备份（demo-03 已验证该恢复路径），删除是低风险高必要运维。
- 各任务只删本 demo 目录；跨 demo 目录由流水线统一清理并 commit（不 add 他 demo 游戏代码）。
