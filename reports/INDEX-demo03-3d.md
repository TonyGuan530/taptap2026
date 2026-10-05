# demo-03 3D 线报告索引（reports/ 为全项目共享目录，本文件只导航 demo-03 3D 线）

> 快速入口：**试玩 v12** https://tonyguan530.github.io/taptap2026/builds/demo-03-3d-v12/ ｜状态交接 reports/2026-10-05-0610-demo03-3d-perf-handoff.md ｜盲测手册 reports/2026-10-05-0310-blindtest-kit-3d.md

## 阶段与版本史
| 报告 | 内容 |
| --- | --- |
| 2026-10-04-demo03-3d-kickoff.md | 工作区/分支/指南启动 |
| 2026-10-04-demo03-3d-phaseAB.md | 阶段 A 规则对照 + 阶段 B 拾取/天气（灰模 v1/v2） |
| 2026-10-05-0010-demo03-3d-v4.md | v4 灭火指挥（主动技能）+ 输入测试 headless 化 + Pages 链路修复 |
| 2026-10-05-0040-demo03-3d-v5.md | v5 风暴之夜 3D 视觉辨识（紫黑夜空/细雨/双层雨） |
| 2026-10-05-0110-demo03-3d-v6.md | v6 第 2 章寒夜守卫（hard 预设，规则变化清单） |
| 2026-10-05-0140-demo03-3d-v7.md | v7 结算遥测面板 + 复制记录 |
| 2026-10-05-0240-demo03-3d-v8-v9.md | v8/v9 Web 缺字修复（emoji/字体子集）+ 浏览器冒烟工具 |
| 2026-10-05-0310-demo03-3d-v10.md | v10 蓄水池（60水/4.5/s/酸雨失效） |
| 2026-10-05-0340-demo03-3d-v11.md | v11 风暴热浪 + fallback 清单收口（冻结声明） |
| 2026-10-05-0440-demo03-3d-v12.md | v12 指南验收矩阵查缺补漏（遥测目标/残留/letterbox） |

## 质量与证据
| 报告 | 内容 |
| --- | --- |
| 2026-10-05-0310-blindtest-kit-3d.md | **真人盲测执行手册**（分组/引导语/判据，入口 v12 PINNED） |
| 2026-10-05-0410-demo03-3d-phaseD-hub.md | 阶段 D 收口：Hub/iframe/build.json 一致性冒烟 |
| 2026-10-05-0510-demo03-3d-video.md | 视频管线（record-video headless 非"屏幕录制"）+ mp4 更新至 v12 |
| 2026-10-05-0540-demo03-3d-balance-sweep.md | 平衡扫描 75 局（弱策略梯度健康/会玩局终局零压力） |
| 2026-10-05-0610-demo03-3d-perf-handoff.md | **性能入账（179fps/SwiftShader 42fps）+ 状态交接文档** |
| 2026-10-05-0640-demo03-3d-input-final.md | 输入矩阵收尾（拖动/滚轮/Q-E/Home 真实事件，46/46） |
| 2026-10-05-0710-demo03-3d-endpanel-e2e.md | 盲测数据通道端到端（真实整局→结算面板→时间线） |
| 2026-10-05-0810-demo03-3d-pages-compliance.md | Pages 清理令合规 + v12 PINNED 保护 |

## 评审与需求对照
| 文件 | 内容 |
| --- | --- |
| reports/miro-fidelity-3d.md | Idea Fidelity：Miro 卡片级承诺逐条兑现 + 大愿景取舍清单 |
| reviews/chatgpt-demo-03-3d-v*-pending.md | v4~v12 九份备案草案（待可占用鼠标时段发送） |
| reviews/chatgpt-conversations.json | 备案索引（phase3d* 键） |
| requirements/backlog.md（main） | 3D 线台账分节（2026-10-05 收录） |

## 运维工具（全部 headless）
browser-smoke / hub-smoke / endpanel-check / record-video / perf-fps（PERF_SW=1 弱机）/ verify-release / subset-font——用法见 reports/2026-10-05-0610 交接文档与 reviews/STANDING-CONSTRAINTS.md。
