# Demo08 折纸工作台重设计

用户目标：上一版仍不好用，重新设计，参考建模软件和开源方案；保持五关，直接完成并上传。

方案比较：继续无手柄拖纸片无法消除选面/视角歧义；完整 Origami Simulator GPU 弹性求解移植成本大；选择独立 Godot 3D 工作台与可重放的折痕模型。参考 Blender 的受约束旋转手柄、Origami Simulator 的折角控制、FOLD/Rabbit Ear 的纸材拓扑表达；不直接引入 GPL Rabbit Ear 或声称移植其求解器。

主流程：大 3D 工作区，默认选面。新折痕模式先选面再选同面两点，角点/边中点吸附，显示端点与折线，活动侧高亮。用始终可见的角度滑条/数值与屏幕旋转手柄预览，确认或取消；ESC 取消本次操作。左侧折痕列表可重选先前折痕，改变它后重放后续折痕，保持相邻面连接；撤销/重做覆盖完整操作。右键环绕，中键平移，滚轮缩放，正视/俯视/适配按钮。纸张正背面不同颜色，边与折痕清晰，不用自动转动相机。

数据：paper_model.gd 维护原始纸材坐标中的折痕、活动侧、绝对角度、基底与事务。现有 paper_geometry.gd 负责面片切分、附着面旋转、网格与气动力输入。origami_editor.gd 独立负责 UI/拾取/吸附/手柄；主场景仅接收模型更新和试飞请求。空白纸全手动编辑；纸飞机起点将原五步的前四步作为载入基底，翼折角作为一个可编辑特征，后续特征均可重选。封闭刚性环或无效折痕明确拒绝，不切断纸面。

约束：3D 世界 + 2D UI；所有 Godot 无头验证，不打开窗口；主场景其他 Demo 不变；只五关；模型编辑与浏览视角分离；未确认事务不能漏入试飞；相同最终面片参与飞行。模型为刚性铰链近似，不含自接触/弹性/CFD。

验证：纸材面积和边长、两折后修改第一折、取消恢复、撤销/重做、无效输入不改几何；实际鼠标选面画线吸附，滑条/手柄与数值一致，视角改变不修改纸张，试飞接收到最终网格；五关回归及线上真实操作、产物 hash。

参考：
- https://docs.blender.org/manual/en/2.90/scene_layout/object/editing/transform/control/gizmos.html
- https://github.com/amandaghassaei/OrigamiSimulator （MIT，参考交互与算法结构）
- https://github.com/edemaine/fold
- https://github.com/rabbit-ear/rabbit-ear （GPLv3，参考数据表达，不复用源码）
