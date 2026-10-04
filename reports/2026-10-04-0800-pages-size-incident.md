# 事件记录 · GitHub Pages 站点超限致部署失败（2026-10-04 08:00）

## 现象

- demo-03-v13 构建（3827b7a，origin 已确认含 build.json version=demo-03-v13）推送后 1 小时+，Pages 仍 404；历史版本（demo-03-v12 等）仍正常服务（=最后一次成功部署的快照）。
- 近几个版本 Pages 部署延迟逐版拉长（v9 ~10 分钟 → v11 ~15 分钟 → v13 >60 分钟未生效）。

## 根因（高置信推断）

- `git ls-tree -r -l HEAD builds/` = **4,114 MB**（84 个构建目录 × ~54MB，全仓库 HEAD 树 ~4.2GB）。
- GitHub Pages 站点体积软限制 **1GB**。HEAD 树远超限制 → Pages 部署失败/排队不放行，站点停留在最后一次成功部署的快照。
- 这解释了近版本所有 demo 的"Pages 生效越来越慢/不生效"现象（demo-02/05/06 等守望日志中的类似迹象）。

## 已处置（本 demo 范围内）

- 9604869：删除 builds/demo-03（v1）及 demo-03-v2~v11 共 11 个旧版目录（保留 v12/v13），**释放约 600MB**；旧版本可从 git 历史与 itch butler 恢复。
- 注意：仅本 demo 瘦身（4.1GB→3.5GB）**不足以**恢复 Pages 部署——仍超 1GB 一倍以上。

## 【需用户决策】全库旧构建清理

- 恢复 Pages 需要将 HEAD 的 builds/ 降到 1GB 以内：其余 demo（01/02/04/05/06/08/09/10/11 + v0.0.x）的旧版目录约 3.5GB 需各自主任务或督导统一清理（保留各自最新 1~2 版即可，旧版本 git 历史与 itch butler 均可恢复）。
- 或改用其他分发渠道（如 itch 各 demo 独立频道 / 单独 artifacts 仓库），Pages 仅留站点壳。
- 决策前，Pages 渠道视为降级：新版本可玩性以 **itch 频道头**为准（当前 v13 已推，但ler 确认）。

## 当前可玩渠道（demo-03）

- itch：https://sxguan.itch.io/taptap2026 （频道头 demo-03-v13，butler 确认；密码 taptap）
- Pages：https://tonyguan530.github.io/taptap2026/builds/demo-03-v13/ （暂 404，待全库清理后随部署恢复）
