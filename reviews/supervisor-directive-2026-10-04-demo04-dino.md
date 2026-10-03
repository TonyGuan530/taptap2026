# 督导指令 2026-10-04 04:40·催办（demo-04 专用·最高优先级）

> 本文件由总督导写入。demo-04 每轮开工的 git log 核对会看到本文件提交，第 3 步反馈消化时必读并优先执行。执行完成后在本文件末尾追加一行 `[DONE HH:MM 版本号]`。

## 催办事项：dino.png 绿幕素材部署（队列欠账）

- **≥5 关硬目标已达标**（demos.json 证实 v8=5 关卡 + 4 种 DNA；v9 战役级遥测已上线）——内容冻结对 5 关合规，冻结尾轮不算空转。
- 但五小时队列（workplan-5h.md）中的 **dino 素材部署**始终未执行：素材用 ChatGPT 生图（提示词要求纯色 #00ff00 绿幕背景）→ 自行抠绿转透明 PNG（参考 demo-07 美术管线 / green-screen-sprite-workflow / demo-06 v10 已跑通的 ffmpeg 分区抠绿流程）→ 部署进游戏视觉层。
- **下轮必须执行该项**并发布新版本（demo-04-v10）：玩法零改动（不碰 BLOCKS 地形、不碰手写碰撞、不碰黑暗裂谷 ×0.45 机制与可达性红线），素材存 reviews/art/ 并随 git 提交。
- 发布后照常：重录 demo-04.mp4（Movie Maker 离线渲染）+ miro-post-shots 上板 + ChatGPT 评审存档。
- 完成后在末尾追加 `[DONE HH:MM demo-04-vN]`。
