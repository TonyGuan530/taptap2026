# demo08 v29 折纸工作台

用户认为 v28 仍不好用，要求参考建模软件与开源方案重新设计。本版提供独立 3D 工作区、网格/光照/阴影/正背面区别，明确的选面与吸附折痕流程、旋转手柄、滑条和数值折角、确认/取消。可从折痕列表重选先前折痕，原始纸材坐标中的后续操作随之重放；撤销/重做覆盖整个模型与空白纸切换。飞机起点的基础四折作为载入几何，翼角作为可编辑特征；手工空白纸的每一条折痕均可重新调整。右键环绕、中键平移、滚轮缩放与适配视图独立于模型。试飞禁止使用未确认预览；相同纸面面片进入物理模型。只五关，其他 Demo 保留。

参考与取舍：Blender 约束旋转手柄，Origami Simulator 折角控制，FOLD/Rabbit Ear 原始纸材拓扑；不直接复用 Rabbit Ear GPL 源码或声称移植 Origami Simulator GPU 弹性求解。新模块为 Godot 自行实现，保留已有 MIT Addmix 气动力曲线和许可。刚性铰链/近似气动力，不支持弹性、自接触或 CFD；闭环刚性约束拒绝，避免撕裂纸面。

验证：新模型 20 项测试，包括两折后改第一折、面积守恒、取消、撤销重做、空白纸撤销、NaN/无效折痕、未确认历史重选回归；真实场景工作台测试，包括两次倾斜面选择、数值与手柄同步、预览不能发射、最终几何试飞。既有物理、五关和真实场景三套回归通过。Godot MCP Pro 脚本验证有效，编辑器错误 0；全部 Godot QA 无头执行。最终浏览器与发布核验待补录。

原生证据：reviews/test_demo08_workbench_model-v29.txt、reviews/test_demo08_workbench_ui-v29.txt、其余 test_demo08_*-v29.txt。

来源：
- https://docs.blender.org/manual/en/2.90/scene_layout/object/editing/transform/control/gizmos.html
- https://github.com/amandaghassaei/OrigamiSimulator
- https://github.com/edemaine/fold
- https://github.com/rabbit-ear/rabbit-ear

最终本地浏览器 2026-10-07T09:15:52.151Z：实际鼠标选面、边中点吸附、两次倾斜面折叠、数值输入、旧折痕调整、取消复原、实际旋转手柄90度、撤销重做、空白纸撤销、环绕/平移/缩放不改几何均通过；示范飞机和五关全通，运行错误0。独立代码复核发现的未确认历史重选错误已修复，复核无剩余 Critical/Important。导入/导出 exit0 且 HTML/JS/WASM/PCK 均存在。

线上核验：产品提交5c05d65f3c600d3c8fdf4183571424d6df48ca58，Actions37599665983 的 build/deploy-pages 均 success，itch 跳过。2026-10-07T09:21:24.612Z 的线上实际工作台45项检查全通过，错误0；包括吸附画折痕、未确认历史重选、数值角度、祖先折痕重调/取消、实际手柄90度、撤销重做、空白纸撤销、浏览视角不改几何、示范飞机试飞和五关连续通过。大厅v29与v28归档验证；线上PCK SHA256 5affbd8d314cb6eff93197e698240611fec4f9ab329812d4a03ad6b0762ba4de 与最终本地导出一致。

试玩：https://tonyguan530.github.io/taptap2026/builds/demo-08-3d-v29/index.html
