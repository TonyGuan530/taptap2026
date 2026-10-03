# demo-05 V8 旋钮裁决（V7 干净 240 局数据后）

- 对话：https://chatgpt.com/c/6abf4a9c-3e7c-83ec-a5f5-6a87251014dd
- 时间：2026-10-04 00:55
- 汇报：容量移除后 240 局（all_cave 100%/78 双料第一、intel 73.3%/72.1；Gate A FAIL B PASS C FAIL）+ 三个现成旋钮拟请裁决

## ChatGPT 回复全文

当前判断：V8 不该碰②，高地二选一会削弱 intel；也不该单独做③，因为它修的是 valley_relocate，不解决 all_cave dominance。 按你们当前数据，唯一正确的主刀方向是①，但我不建议只把 cave tax 调到 2食2水。

裁决：V8 做「① + ③」，数字如下
Cave tax：1食1水 → 3食3水
抢运洒落：25% → 15%
其余全部冻结：泥流50%、7采集、路线12/14/16、高地双收益、天气概率、A'评分全部不动。

不做②。

理由很直接。

为什么 cave tax 不是 2食2水，而是 3食3水

你们自己已经算出：

当前 all_cave：稳定余量4 → 78分
2食2水后：余量2 → 74分

而当前 intel 是 72.1。

即使先粗略忽略 tax 同样会影响 intel 的雨天洞穴局，74 仍然没有把 all_cave 明确压到 intel 以下。更麻烦的是，intel 雨天也依赖洞穴，所以提高 cave tax 会同时拉低 intel，只是影响频率低于 all_cave。

因此 2/2 很可能只是把差距缩小，而不是解除 dominance。

我建议直接测 3食3水。它的设计语义也更清楚：

洞穴不是“免费保险 + 小手续费”，而是“用相当明显的资源效率换绝对安全”。

按当前余量关系，all_cave 会从稳定 surplus 4 被压到接近 surplus 0，也就是大约 70分级的稳定惨胜。这正符合我们一直希望它承担的角色：

100%活，但只是保命。

不是把它杀到75–90%生存率。

为什么同时把抢运 25% → 15%

因为 V7 已经暴露了另一个确定的问题：

valley_relocate = 0%

这说明我们最早认为最能体现“世界变化 → 临场重构方案”的玩法，反而已经从策略空间里彻底消失了。

这是不能接受的。

抢运 是这个 Demo 最有价值的 emergent/emergency mechanic 之一。当前 25% 洒落 + cave tax + 路线成本叠加，导致它 mathematically non-viable，这不是“高风险”，而是假选择。

将洒落从 25%降到15% 是最窄的修正：

不新增机制；
不改变天气；
不降低全局难度；
只恢复一个已经存在的 strategy archetype。

而且 cave tax 提到 3/3 后，抢运本来会进一步受伤，所以这两个数字应该一起调。

这符合 supervisor-prompt 要求的原则：优先少量改动，但让现有机制重新产生有效选择，而不是堆新内容。
GitHub

为什么明确不做②「高地收益二选一」

现在 intel_play 不是需要削弱的对象。

它：

生存率73.3%，并非过高；
均分72.1，也已经低于 cave；
它还是当前最符合设计主题的主动策略之一——玩家购买信息，然后利用真实天气调整计划。

砍掉“预报准确 / 路线-1”之一，只会把：

主动获取信息、根据世界变化决策

变得更差。

这和我们最初想鼓励的行为方向相反。

如果未来 intel 真变成 95%+ 生存且最高分，再讨论拆高地双收益。

现在不要因为它叫“情报派”看起来聪明就先削它。

V8 只看这三个结果

不需要再造一套复杂 Gate。

Gate 1 — Cave role

目标：

all_cave = 100% survival 可以保留，但 mean score < 主动策略最高均分。

我希望看到大约：

all_cave：100% / ~70

不用追精确数字。

如果它100%活、70分，这已经是非常清晰的：

Safe floor strategy。

Gate 2 — Emergency recovery

valley_relocate 必须重新出现。

最低要求：

overall survival > 0%，最好进入 20–60%。

更关键的是雨天：

抢运必须至少有部分雨天局能把必死状态救成活。

否则这张 Emergency Action 卡没有验证价值。

Gate 3 — Strategy frontier

我希望最终开始出现这种 Pareto 关系：

Strategy	Survival	Score / Quality
all_cave	最高	低
intel	中高	高
relocate	中等	成功时高
even5	中等	中
pure gamble	低	成功时不错

没有一个 strategy 同时拿“最安全 + 最高收益”。

这才是比“每个策略必须75–90%”更正确的平衡目标。

Gate A 的雨天问题这轮暂时不要再追

V7 里 Gate A 仍 FAIL，但我现在不建议再为了“至少两个非洞穴策略雨天20–70%”去调泥流。

原因是 valley_relocate 当前为0%，它本来就应该是第二个重要的雨天中间策略。

先通过 15%洒落 + cave tax 3/3 看它能不能恢复。

如果恢复以后形成：

all_highland：雨天中间态；
valley_relocate：雨天中间态；
intel：雨天高成功；
裸押 valley/forest：雨天低成功；

实际上这个风险谱已经比机械要求所有 policy 都进20–70%更健康。

V8 后停止自动调参的条件

如果这一刀后：

all_cave 仍100%，但不再最高分；
valley_relocate 从0恢复为有效策略；
风向 Gate B 仍 PASS；
没有新的单一“双料第一”；

那么：

直接进入真人 5 局。

即使某些 policy 数字不漂亮，也不要继续 V9 spreadsheet tuning。

Supervisor prompt 的目标是快速判断玩法是否值得继续，而不是把 prototype 调成竞技游戏的正式平衡。它明确要求 GameJam 阶段优先“最小修改、最大验证信息量”。
GitHub

当前结论

ITERATE — 最后一刀：

cave tax 3食3水 + 抢运洒落15%。

其他参数全部冻结。

这刀的目的不是“让统计表更平均”，而是把当前策略图从：

洞穴 = 最安全也是最好；抢运 = 假选择

修成：

洞穴 = 稳定保命；情报 = 主动高质量；抢运 = 真正能救错局的高风险补救。

如果 V8 数据证明这三个战略身份同时成立，就停止模拟，转真人 Gate。
