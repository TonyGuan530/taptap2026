# demo-02 收束修复交付（2026-10-07）

用户最终试玩反馈：2D 第三关卡住但能理解玩法；3D 第一关无法通关；3D 明确改第三人称。用户随后明确要求反馈后直接修改。本轮已修改实际源码并交付两份 Web 构建，真人验收待复测。

## 实际改动

- 2D v8：第三关舱室前移 60px，弹簧中心到舱门由 460px 缩至 400px（约 13%）；舱顶仍需重物砸穿，舱底接收区加宽；1/2/3 可直接切词条；换关清除旧通关文字。
- 3D v16：从 `codex/demo02-3d` 的 v15 源码（9429636）引入场景及已有 comic 库，在当前隔离工作区补齐可见球体、词条颜色和第三人称相机避障。第一关初始朝向由侧墙改为目标方向，等待首次键盘操作后发射，放宽墙后接收带；加入通关文字、下一关按钮和 N 键。保留 V 切换第一人称。
- 原来的 3D 测试会手动修正 yaw，新专项测试保留真实默认视角与出生位置。旧 L3 测试在 x=9.5 才松 W，会靠羽毛惯性滑至 x≈13.26 而错过目标，且循环无超时；已按上岸点 x=8 松 W，并补充有限帧等待。其他关卡几何及物性参数未在本轮改动。
- 已安装并启用 Godot MCP Pro addon；通过无窗口编辑器确认其能连接此工作区。插件侧未提供本会话工具定义中的 `run_headless_script`，回归测试使用 Godot CLI。全程 Godot 命令带 `--headless`，浏览器使用 headless Edge。

## 验证证据

- `node tools/verify-demo02-closing.mjs`：30/30 通过。覆盖 2D v4-v7 既有回归、0/0.3/0.8/1.2 秒操作延迟、换关提示清理、3D 八关既有 15 用例、默认第三人称、V 切换、第一关等待操作、下一关按钮、石头错误解法对照及 30/60/120Hz。
- `./tools/export-demo02-closing.ps1`（PowerShell 7）：使用用户指定 Steam Godot 4.7.2，无窗口 import/export 均退出 0；两版 HTML/JS/WASM/PCK 齐全。临时最小工程仅导出各 Demo 场景及依赖，未改其他 Demo 的主场景，也未将 MCP 运行时服务打入新构建。
- `node tools/browser-demo02-closing.mjs`：真实 Web 导出在 headless Edge 启动。3D 按 3 后按住 W，L1 约 2.3s 通关，点击下一关进入 L2；2D 实际通关 L1/L2/L3，L3 一次扑翼、2 键切石头砸板，约 7.5s 通关、零重置。两版 console/page error 均为 0。
- 原始结果：[CLI 回归](../reviews/demo02-closing-validation.json)、[浏览器记录](../reviews/demo02-closing-browser.json)；截图位于 `reviews/shots/demo-02-3d-v16-*.png` 及 `reviews/shots/demo-02-v8-L3-*.png`。
- PINNED `builds/demo-02-3d-v10` 未修改；当前 `builds/` 约 731.5 MiB，低于 800 MiB 红线。

## 复测与发布状态

- [2D v8 本地试玩](http://localhost:8792/builds/demo-02-v8/index.html)
- [3D v16 本地试玩](http://localhost:8792/builds/demo-02-3d-v16/index.html)

当前工作区 Review 服务监听本机 8792，健康接口 `ok=true`、16 个构建。本地 `public/demos.json` 槽位指向 v8/v16；反馈台账已回应 FB-101，补记 FB-110/111，仍待真人复测。本轮未提交、推送或部署 GitHub Pages，原线上试玩地址仍为旧版。

## 后续发布指令（2026-10-07）

用户在询问是否上传后澄清「那你上传最新的版本就行」。以本条最新指令为准：取消 02—3D 归档决定，保留现役 3D v16，并发布 2D v8 / 3D v16。旧版仅作为历史构建保留；PINNED v10 不删除。发布验收以 Pages 部署回执及线上实际构建为准，前述「本轮未推送」描述的是本地交付时的状态。
