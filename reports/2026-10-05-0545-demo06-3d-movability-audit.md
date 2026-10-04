# 流水线报告 · demo-06 3D 12 组合可移动性审计（L7 前置）

- 时间：2026-10-05 05:45（04:55 场次续）
- worktree：D:\GIT\taptap2026-demo06-3d（分支 codex/demo06-3d-migration）
- 依据：ChatGPT 裁定「先做 12 组合可移动性审计（三问），再设计 L7 借板登岸」
- 测试：game/tests/test_demo06_3d_movability.gd（每组合真实放置→落定→玩家贴身推 90 tick→测位移/冻结/持久/漂移；EnvCrate 对照）

## 三问结果（实证数据）

| 问 | 结果 |
| --- | --- |
| ① 生成后能否被推 | **仅 ball+heavy（滚 1.087m）**；其余 11 组合位移 0.000 |
| ② 永久冻结/快速失 operability | Float 即冻结、Sticky 0.4s 冻结、Fire 2s 自毁——9/12 按既定规则不可复用，无意外 |
| ③ 假可移动 | ball+heavy「能推但会滚走」（推后 120 tick 自由滚动 1.612m，需地形挡停）；heavy plank/block 非"假可移动"而是**真不可移动**（mass8×gravity×2.6×friction≈203N >> 玩家推力 25N） |

EnvCrate（无词条）对照：推 2.788m 可动 ✓（与 L3 C0 实跑一致，测量链自洽）。

## 关键数据

- 全明细：ball+heavy push=1.087 drift=1.612 MOVABLE；其余 11 组合 push=0.000；测试退出码 0，无异常/NaN。
- 摩擦构成：放置物无 PhysicsMaterial（默认 1.0）× Heavy gravity_scale 2.6 → 法向力 8×9.8×2.6≈203N。

## L7 设计影响（供评审裁定）

- 裁定设想的「Heavy 长板可复用」在现有规则下**不成立**（plank/block 不可滑移，203N vs 25N；gravity_scale 2.6 是核心规则不可动）。
- 规则内唯一可复用物 = **ball+heavy（40 墨，滚动/持久/会滚走）** → 「L7 借球登岸」：球滚入第一问题当垫脚/配重，再滚到第二问题复用；「会滚走」 trait 本身可成为关卡张力（需地形挡停设计）。
- 备选（3D 原生复合复用）：ball 撞动已放置的 heavy plank——单次冲量仅微移（203N 摩擦），多次撞击边缘可行——复杂度高，倾向不做。

## 本轮无构建发布（纯审计轮，无玩法改动）；L7 实现轮随 v6 发布。
