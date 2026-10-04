# demo-03 3D 线 · 常驻约束（用户指令，优先级高于流程模板，每轮开工先读）

1. **禁止弹窗/占鼠标**（2026-10-05 用户指令「不要再打开 godot 前端开发抢我鼠标」+「不要做弹出游戏的QA」）：
   - 一切 Godot 操作只用 `--headless`（D:\GIT\taptap2026\tools\godot\Godot_v4.7.2-stable_win64_console.exe）。
   - 输入管线测试已 headless 化（test_demo03_3d_input.gd 21 断言），不要再窗口化运行。
   - **Movie Maker 视频重录暂停**（需窗口）。视频/Miro 更新推迟到用户明示可用时段；报告如实标注视频落后于最新构建。
   - **ChatGPT 浏览器自动化暂停**（占鼠标）。备案写草案存 reviews/chatgpt-demo-03-3d-vN-pending.md，待可占用鼠标时段统一发送归档。
2. 导出/发布照常（headless export、butler、git plumbing 提交 Pages，全程无窗口）。
3. Pages 发布用 plumbing（临时索引 + commit-tree + push origin <sha>:main），**不碰主检出工作区**（那是 2D 线的）；publish-qa.mjs 的 butler -i 调用有超时 bug，用手动等价校验（butler status + CDN 四件套 md5；CDN 占位 md5 0822277b 为已备案问题勿反复重推）。
4. Pages builds/ 已 1.2GB 超 1GB 软限（部署目前仍成功）；**全局瘦身需用户决策**，未经决策不要擅自删其他 demo 的构建。
