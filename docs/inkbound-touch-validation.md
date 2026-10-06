# INKBOUND V10 触控补丁验证

混合项目：3D世界与角色，2D绘画和输入界面。

- 源提交：77bd6581e91c02ec9e039285253af76090c05db3
- PCK SHA-256：d33c9bcc249dac424484f0a21fdee18a31a49642f79a30a891954885d0368b5b
- Godot 4.7.2，无窗口导入、启动、导出均 exit 0。
- 原生 147 项检查通过，无 stderr；覆盖真实移动、多指同时操作、取消与失焦、笔画所有权、画纸穿透拦截、梯顶输入复位。
- 移动浏览器 844×390：实际 CDP 触摸绘画、移动、攀爬、切藤、战斗、双指移动与跳跃、完整结局。
- 桌面鼠标与键盘：板面路线＋搭梯绕过保留的藤墙和敌人，完整结局。
- 两条浏览器路线接收到的实际 HTTP PCK 都与本地导出一致，控制台无错误。
- 验证设备为 Chromium 模拟移动浏览器，未使用实体 Android／iOS 手机。

保留旧 V10 导出和录屏；原录像仍对应原版哈希。当前补丁验收的是操作与原有流程，不能作为新版涌现玩法已完成的证明。新设计见 [改版案](inkbound-emergence-redesign.md)。

线上发布：提交 7fcc1cab5423e796cfc96088e84f49669c69792f，GitHub Pages [工作流 37512457979，第 2 次运行](https://github.com/TonyGuan530/taptap2026/actions/runs/37512457979) 成功。实际线上 PCK 与验收构建一致；手机浏览器真实触摸完成开始、摇杆移动、四笔绘画与保存，控制台无错误。

[触控试玩](https://tonyguan530.github.io/taptap2026/builds/demo-06-inkbound-v10-touch/index.html) · [展示页](https://tonyguan530.github.io/taptap2026/inkbound-v10.html)。
