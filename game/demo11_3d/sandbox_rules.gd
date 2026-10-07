extends RefCounted
## DEMO11 3D 版格子规则核心（阶段 A 兼容基线）
## 从 game/demo11_sandbox.gd 逐行移植：12x7 格、索引 y*12+x、正交一格、整数状态权威。
## try_move / try_tool / advance_time 先完成整数状态更新并产出事件数组，表现层只读事件做 80ms 插值；
## 本类不引用材质、镜头、场景路径，无刚体、无物理/射线参与规则判定。
##
## 兼容基线（证据见 reports/demo11-3d-rule-audit.md，差异编号同指南第 3 节）：
## - 差异1：铁块被直接推入水/坑与木箱同路——造 bridge/fill、遥测不增 object_move、序列硬编码 push:box:*；
##   融冰分支铁块仍沉水回 water。两条路径的语义不一致是现状，不得在本文件"顺手修正"。
## - 差异2：推物/磁拉落点仅接受 floor/ice。
## - 差异3：fire 先烧面前木箱，冰上有箱时融冰分支不可达。
## - 差异5：family 分类器保留精确串 "tool:fire:melt"——带方向的 "tool:fire:melt:方向" 永不命中 melt_route。
## - 差异6：load_room/restart() 不清 tele/steps/rooms_cleared/family_by_room（旧 _restart 语义）；
##   reset_sample() 是新增显式"新样本"入口（整局重开全清，样本不混旧记录），其余旧语义未动。
## 修正提案（统一木/铁语义、融冰分类协议、记录生命周期）均未采用，单独评审后另开变更。
## 定时融化：基线五图不可达（无邻接水的固定热源）；EXT-7 起玩家可达，两个入口：
## ① 冻冰时格子邻接火把（_arm_torch_melt，基线语义）；② EXT-7 新交互——推动 torch_m 落地时
## 点燃其四邻 ice 格的融化倒计时（_arm_melt_around，"挪灶"——可搬运的热源）。
## advance_time 处理 melt_queue 与旧 _process 相同，测试可手动推进 dt 锁定行为。

const ROOM_W := 12
const ROOM_H := 7
const SLIDE_TIME := 0.08        # 表现层插值参照（秒）；核心不做时间插值
const TORCH_MELT_TIME := 3.0    # 火把旁冰面融化秒数
const PHASE_OPEN_TIME := 2.0    # EXT-13 相位门：每周期开启时长（秒）
const PHASE_PERIOD := 4.0       # EXT-13 相位门：开合周期（开 2 秒 + 关 2 秒）
const VENT_PERIOD := 4.0        # EXT-17 间歇泉：喷发周期（秒），融化四邻冰
const CART_PERIOD := 1.0        # EXT-35 暖轨车：巡轨步进周期（秒），撞阻反转该拍原地
const BELT_PERIOD := 1.0        # EXT-40 输送带：整拍步进周期（秒），带上物/人沿带向一格

const DIR_VECS := {up = Vector2i(0, -1), down = Vector2i(0, 1), left = Vector2i(-1, 0), right = Vector2i(1, 0)}

## 房间表与旧版逐字一致（#墙 .地板 ~水 O深坑 S开关 G终点门 P起点 B木箱 I铁块 T火把）
const ROOMS := [
	{name = "房间1 · 推动入门", tools = [], tip = "把木箱推上圆盘开关压住，终点门才会开。两只木箱方向随便挑：上面的箱往下推、下面的箱往右推，至少两条走法。",
		map = [
			"############",
			"#P.........#",
			"#....B.....#",
			"#..B.S.....#",
			"#..........#",
			"#G.........#",
			"############",
		]},
	{name = "房间2 · 水面", tools = ["ice"], tip = "水挡住了去路。解法A：把木箱推进水里沉成桥面走过去；解法B：冰霜杖（F）把面前一格的水冻成冰面。小心别把唯一的木箱推进坑里。",
		map = [
			"############",
			"#P...~.....#",
			"#....~.....#",
			"#..B.~....G#",
			"#....~.....#",
			"#..O.~.....#",
			"############",
		]},
	{name = "房间3 · 焚烧", tools = ["ice", "fire"], tip = "木箱堆堵住了开关。解法A：火把（G）烧掉开关旁的木箱，再把散箱推进去压住；解法B：不烧，把散箱从下路绕推过去，一样能压住开关。",
		map = [
			"############",
			"#P....T...~#",
			"#..B..B....#",
			"#....BS....#",
			"#..........#",
			"#........G.#",
			"############",
		]},
	{name = "房间4 · 磁石", tools = ["magnet"], tip = "铁块锁在围栏里。解法A：磁石（H）隔空把同排、中间无墙的最近铁块一格格拉到开关上；解法B：绕进围栏推着铁块走长路从缺口出来。",
		map = [
			"############",
			"#P....#....#",
			"#.....#....#",
			"#.S......I.#",
			"#.....#....#",
			"#.....#..G.#",
			"############",
		]},
	{name = "房间5 · 开放实验房", tools = ["ice", "fire", "magnet"], tip = "目标：让两个开关同时压住，抵达终点门。物件说明：木箱可以推动，推进水里会沉底变成桥面；铁块可以推动，也能被磁石隔空拉近；冰霜杖（F）把面前一格的水冻成可以走的冰面；冰面融化的瞬间，压在上面或踩在上面的事物会失去支撑。用什么组合，由你决定。",
		map = [
			"############",
			"#...~......#",
			"#...~......#",
			"#...~...G..#",
			"#P..~..I.S.#",
			"#.B.~...BSI#",
			"############",
		]},
]

## 机制扩展房间（EXT）：单独表，五房基线逐字不动。EXT-1「火种渡口」= 移动热源机制（M=torch_m，
## 规格见 reports/demo11-3d-ext1-spec.md）。final 在 EXT 通关；room5_complete 仍锁定索引 [4]。
const ROOMS_EXT := [
	{name = "EXT-1 · 火种渡口", tools = ["ice"], tip = "移动火把（M）烤着水面：直接冻冰三秒就化。先把热源推离水边，冻出的冰才是永久的。木箱沉水、铁块压板，老办法也行。",
		map = [
			"############",
			"#P.B~......#",
			"#...M~.....#",
			"#......SI..#",
			"#....~.G...#",
			"#....~.....#",
			"############",
		]},
	{name = "EXT-2 · 空位渡口", tools = [], tip = "凹陷板（N）反着来：空着才导通，被压住反而断开。把铁推上圆板（S），再让凹陷板保持空位——门就会开。",
		map = [
			"############",
			"#P.........#",
			"#.########.#",
			"#....NI.S..#",
			"#..........#",
			"#.........G#",
			"############",
		]},
	{name = "EXT-3 · 薄冰渡口", tools = [], tip = "带裂纹的薄冰（C）只能走一次，走完就碎。人可以走薄冰过去，铁块得靠两只木箱搭双桥——右岸的谜题要自己想办法。",
		map = [
			"############",
			"#P..B~.....#",
			"#....C.....#",
			"#....~.....#",
			"#.B..~..G..#",
			"#....~.SI..#",
			"############",
		]},
	{name = "EXT-4 · 四渡口", tools = ["ice"], tip = "终点试炼：凹陷板（N）上压着箱子，推开它；移动火把（M）守着冻冰的站位；薄冰（C）只能过一次——渡口很多，但铁块必须上圆板。四道机关，一次走通。",
		map = [
			"############",
			"#P..B~.....#",
			"#..n.C.....#",
			"#...M~.....#",
			"#.B..~..G..#",
			"#....~.SI..#",
			"############",
		]},
	{name = "EXT-5 · 淬冰渡口", tools = ["ice"], tip = "薄冰（C）只能走一次——但冰霜杖可以把它淬成坚固的永久冰。淬冰、渡河、踩上圆板，再去右岸想办法。",
		map = [
			"############",
			"#P...~.....#",
			"#....C.....#",
			"#..B.~SI...#",
			"#....~..G..#",
			"#..........#",
			"############",
		]},
	{name = "EXT-6 · 回声祭坛", tools = ["ice"], tip = "回声石（R）会记住你的脚步：踩上去，整个房间就会回到最初的样子。把铁墩推进水里会沉没——推死了也别慌，踩石重来。",
		map = [
			"############",
			"#P.........#",
			"#.R.~......#",
			"#...I.S....#",
			"#.......G..#",
			"#..........#",
			"############",
		]},
	{name = "EXT-7 · 挪灶化冰", tools = [], tip = "木卡在永冰上推不动？把火炉（M）推到冰旁边——冰面撑不了多久。融化了的木箱会沉成桥。小心：火炉也烤化你脚下的路。",
		map = [
			"############",
			"#P.....~####",
			"#.I.S..~####",
			"#....B.AG###",
			"#..M...~####",
			"#......~####",
			"############",
		]},
	{name = "EXT-8 · 单行阀", tools = [], tip = "箭头格只能顺箭头进入（人货同理）——穿过去就回不了头。想好顺序再过阀：木箱先行，你也跟上。",
		map = [
			"############",
			"#P...#.....#",
			"#....#.....#",
			"#..B.>.S...#",
			"#....#.....#",
			"#....#...G.#",
			"############",
		]},
	{name = "EXT-9 · 对影门", tools = [], tip = "成对的传送门送人也送货（EXT-49 起）——货推进门就到对岸。办完事，原门返回。",
		map = [
			"############",
			"#P.....Y...#",
			"#...X#.....#",
			"#....#..I..#",
			"#....#..S..#",
			"#G...#.....#",
			"############",
		]},
	{name = "EXT-10 · 铁敬", tools = [], tip = "刻着铁纹的重压板（W）只认铁墩的分量——人和木箱都压不住它。两块板各归其位，门才会开。",
		map = [
			"############",
			"#P.........#",
			"#..B....W..#",
			"#....I.....#",
			"#..S.....G.#",
			"#..........#",
			"############",
		]},
	{name = "EXT-11 · 焚垣", tools = ["fire"], tip = "墙上那道裂纹在招手——火把（G）能烧塌裂纹墙。当心：火不分好坏，挡路的木箱一样烧。",
		map = [
			"############",
			"#P.B.#.....#",
			"#....K.I...#",
			"#....#.....#",
			"#....#.S.G.#",
			"#....#.....#",
			"############",
		]},
	{name = "EXT-12 · 冰厅", tools = [], tip = "滑冰格停不下来——顺冰道一路滑到头。铁墩是你唯一的刹车：把它推到冰道当止滑器，或者干脆推去压开关。",
		map = [
			"############",
			"#P.........#",
			"#.iiiiI....#",
			"#....i.....#",
			"#....i.....#",
			"#.....S..G.#",
			"############",
		]},
	{name = "EXT-13 · 闸时", tools = [], tip = "相位门按自己的钟摆开合：开两秒，关两秒。别硬闯——在门外等它开，或者算好节奏一次通过。",
		map = [
			"############",
			"#P...#.....#",
			"#....Z.I...#",
			"#....#.....#",
			"#....#.S.G.#",
			"#....#.....#",
			"############",
		]},
	{name = "EXT-14 · 跃泉", tools = [], tip = "弹簧垫会把你弹过两格宽的沟——落点固定，不能选。垫子只送人：铁墩得自己想办法过河（或者根本不用过去）。",
		map = [
			"############",
			"#P..~......#",
			"#...~..I...#",
			"#..J~..S...#",
			"#...~....G.#",
			"#..........#",
			"############",
		]},
	{name = "EXT-15 · 错拍", tools = [], tip = "两扇相位门踩着相反的拍子：蓝门开时棕门关。中间的小口袋是唯一的喘息位——等反拍，一次通过。",
		map = [
			"############",
			"#P..###....#",
			"#...Z.z..I.#",
			"#...###....#",
			"#...###..S.#",
			"#...###.G..#",
			"############",
		]},
	{name = "EXT-16 · 合鸣", tools = [], tip = "铁墩上冰道会打滑——一推就溜到头。冰道的尽头正好是重压板：轻一推，铁就自己归位。相位门在后头等你。",
		map = [
			"############",
			"#P.........#",
			"#.IiiiW....#",
			"#..........#",
			"#.......Z..#",
			"#.......G..#",
			"############",
		]},
	{name = "EXT-17 · 间歇泉", tools = ["ice"], tip = "热泉每四秒喷一次，把旁边的冰化回水。冻好冰就快过——或者算准喷发节奏再动手。",
		map = [
			"############",
			"#P.........#",
			"#...V......#",
			"#...~..I...#",
			"#...~..S..G#",
			"#...~......#",
			"############",
		]},
	{name = "EXT-18 · 一拍即合", tools = [], tip = "绿圈是自锁踏板：踩一下就永远咬合。弹簧送你过去踩一脚，后面的门就再也不会关。",
		map = [
			"############",
			"#P.........#",
			"#..J~LZG...#",
			"#..........#",
			"#..........#",
			"#..........#",
			"############",
		]},
	{name = "EXT-19 · 呼吸桥", tools = [], tip = "寒泉冻水成冰，热泉化冰成水——中间那格桥每四秒冰水交替。看准它结冰的节拍，一口气跑过去。",
		map = [
			"############",
			"#P.........#",
			"#...Q......#",
			"#...~I.....#",
			"#...V...S.G#",
			"#..........#",
			"############",
		]},
	{name = "EXT-20 · 脆壁", tools = [], tip = "褐色裂墙一碰就碎：走上去撞一下，或把箱子铁墩推进去，都会砸出一条永久的路。把铁墩推进裂墙缺口压住开关，再绕到终点门。",
		map = [
			"############",
			"#P...#.....#",
			"#.I..D..S.G#",
			"#....#.....#",
			"#..........#",
			"#..........#",
			"############",
		]},
	{name = "EXT-21 · 三拍", tools = [], tip = "西门只开前两拍，冰桥只在第 2～4 拍结冰，东门和西门同相。错一拍，就要等下一轮循环——过门、抢冰、再候门，听清三拍一气呵成。",
		map = [
			"############",
			"#..#..~..#.#",
			"#..#..Q..#.#",
			"#.PZ..~..ZG#",
			"#..#..V..#.#",
			"#..#..~..#.#",
			"############",
		]},
	{name = "EXT-22 · 暗缝", tools = [], tip = "墙上那道窄缝只有你能侧身挤过去——箱子、铁墩都进不去，磁石也拖不进去。把铁墩安顿到开关上，自己钻过缝去，看看门后是什么。",
		map = [
			"############",
			"#.....#...##",
			"#PI...U..G##",
			"#.....######",
			"#..S.......#",
			"#..........#",
			"############",
		]},
	{name = "EXT-23 · 疑路", tools = [], tip = "那格地板看起来和别处一模一样——踩上去才知道是深坑。重物压上去会当场露馅、沉底填坑；想过去，就得舍得一块垫脚的。",
		map = [
			"############",
			"#G........o#",
			"##########.#",
			"#..........#",
			"#..S.I...B.#",
			"#.....P....#",
			"############",
		]},
	{name = "EXT-24 · 相位桥", tools = [], tip = "这格桥和相位门同拍：开窗是桥，闭窗是水。桥上站太久会被河水请回西岸——看准拍子，两窗连过。",
		map = [
			"############",
			"#...~..#...#",
			"#...~..#...#",
			"#P..w..z..G#",
			"#...~..#...#",
			"#...~..#...#",
			"############",
		]},
	{name = "EXT-25 · 终演", tools = [], tip = "相位桥、呼吸桥、反相门——时间机制三兄弟同台。开窗过相桥，等冰窗一口气连过呼吸桥和反相门；错一拍，等一轮。这是全部三十房的终演。",
		map = [
			"############",
			"#..~####...#",
			"#..~#Q##...#",
			"#P.w.~.z..G#",
			"#..~#V##...#",
			"#..~####...#",
			"############",
		]},
	{name = "EXT-26 · 弹射", tools = ["ice"], tip = "青色的弹射垫会把推上来的货物沿推向弹出去两格——水再宽也拦不住飞行的箱子。把木箱弹过对岸，自己再想办法过河。",
		map = [
			"############",
			"#....~.....#",
			"#....~.....#",
			"#P.Bk~...SG#",
			"#....~.....#",
			"#....~.....#",
			"############",
		]},
	{name = "EXT-27 · 联桥", tools = [], tip = "紫环开关压住的不是门，是河面上那格桥。人踩开关桥就断——得把箱子请上去压住，桥才会为你常开。过河之后，还有铁墩和开关等着。",
		map = [
			"############",
			"#....~.....#",
			"#..B.~.....#",
			"#P.b.e.I.SG#",
			"#....~.....#",
			"#....~.....#",
			"############",
		]},
	{name = "EXT-28 · 双联", tools = [], tip = "两座紫环开关各管半座桥——缺一座，河就是完整的河。两箱各就各位，桥才肯连成一线。过河之后，铁墩和终点都在对岸。",
		map = [
			"############",
			"#....~~....#",
			"#.bB.~~.IS.#",
			"#P...ee....#",
			"#.bB.~~...G#",
			"#....~~....#",
			"############",
		]},
	{name = "EXT-29 · 油道", tools = [], tip = "紫色的油道只伺候木箱：推上去就一路滑到头，铁墩可不吃这套。让木箱自己滑到该去的地方，你跟着油路走就是。",
		map = [
			"############",
			"#..........#",
			"#.B.gggggS.#",
			"#P.......G.#",
			"#..........#",
			"#..........#",
			"############",
		]},
	{name = "EXT-30 · 联运", tools = ["ice"], tip = "油道的尽头接着弹射垫——箱子滑进垫里还会再弹两格，宽宽的河一次飞过去。你踩着冻住的河面跟上，把落点的箱子往右一推，门就开了。",
		map = [
			"############",
			"#......~...#",
			"#......~...#",
			"#P.Bggk~.SG#",
			"#......~...#",
			"#......~...#",
			"############",
		]},
	{name = "EXT-31 · 潮汐", tools = [], tip = "这片滩涂跟着大潮呼吸：前四秒露出泥面，后四秒沉入水底。踩滩要赶在露潮，过门要赶在反拍——八秒一个轮回，别跟丢了。",
		map = [
			"############",
			"#..~..#....#",
			"#..~..#....#",
			"#P.u..z..G.#",
			"#..~..#....#",
			"#..~..#....#",
			"############",
		]},
	{name = "EXT-32 · 联运潮滩", tools = ["ice"], tip = "潮汐滩涂过后，紫油道会把木箱一路送进弹射垫，隔着河直接压住开关。人走冰面跟上——先箱后人，各走各的桥。",
		map = [
			"############",
			"#......~...#",
			"#PuBggk~S..#",
			"#........G.#",
			"#......~...#",
			"#......~...#",
			"############",
		]},
	{name = "EXT-33 · 换乘", tools = [], tip = "两片滩涂错着拍子呼吸：这片露的时候那片淹着。先踩露潮滩等换乘窗，两滩同露的瞬间跨过去——之后那片能扛到下一个轮回。",
		map = [
			"############",
			"#.~~.......#",
			"#Puj..I..SG#",
			"#.~~.......#",
			"#.~~.......#",
			"#.~~.......#",
			"############",
		]},
	{name = "EXT-34 · 推凿", tools = [], tip = "灰蓝色的假墙人撞不动——但箱子推上去会把它凿塌。一路把箱子推过去，它自己会压住开关。硬碰硬，是箱子的工作。",
		map = [
			"############",
			"#..........#",
			"#P.B...y.SG#",
			"#..........#",
			"#..........#",
			"#..........#",
			"############",
		]},
	{name = "EXT-35 · 暖轨", tools = [], tip = "轨道上的暖车会自己巡逻：它烧木箱、化冰面，谁也推不动它。趁它还没折返，把箱子送到该去的地方。",
		map = [
			"############",
			"#..........#",
			"#P.B..AA.c.#",
			"#..........#",
			"#..S.....G.#",
			"#..........#",
			"############",
		]},
	{name = "EXT-36 · 钥匣", tools = ["ice"], tip = "锈红色的门不吃那一套开关把戏——它只认钥匙。沉箱为桥，冻河为路，黄铜的信物就在对岸等着。",
		map = [
			"############",
			"#..........#",
			"#P.B..~~.dE#",
			"#..........#",
			"#..........#",
			"#..........#",
			"############",
		]},
	{name = "EXT-37 · 藤垣", tools = [], tip = "青绿的藤墙人能攀过去，箱子与铁块只能望墙兴叹。西屋的开关要箱子压，东屋的踏板要你去踩——两件事，隔着一道藤。",
		map = [
			"############",
			"#.B.S.l..L.#",
			"#.....l....#",
			"#P....l...G#",
			"#.....l....#",
			"#.....l....#",
			"############",
		]},
	{name = "EXT-38 · 晶屑", tools = ["ice"], tip = "冰晶推一下就碎成一汪清水——只有一次机会。把它推进坑里，冻上，就是你的桥。",
		map = [
			"############",
			"#.....O....#",
			"#P...xO...G#",
			"#.....O....#",
			"#.....O....#",
			"#.....O....#",
			"############",
		]},
	{name = "EXT-39 · 换相井", tools = [], tip = "井是踩得出来的时间：一脚下去，潮汐与门相一起翻转。两滩永不同开的地方，找井踩两脚。",
		map = [
			"############",
			"#..........#",
			"#Pq.j.q.u.G#",
			"#..........#",
			"#..........#",
			"#..........#",
			"############",
		]},
	{name = "EXT-40 · 输送", tools = [], tip = "灰色的带子每秒走一格：把箱子推上去，它自己会驶向开关。你也可以踩上去搭车——或者站在前面，让货等你。",
		map = [
			"############",
			"#..........#",
			"#P.BfffffSG#",
			"#..........#",
			"#..........#",
			"#..........#",
			"############",
		]},
	{name = "EXT-41 · 经纬", tools = [], tip = "东西的带子接上南北的带子，货就会自己拐弯。铺一条会转弯的流水线，剩下的交给节拍。",
		map = [
			"############",
			"#..........#",
			"#P.Bfm.....#",
			"#....m....G#",
			"#....m.....#",
			"#....S.....#",
			"############",
		]},
	{name = "EXT-42 · 双钥", tools = [], tip = "银门只认银钥，金锁只认金钥——两把钥匙、两种门，把行程排成一条线。别拿错，也别走回头路。",
		map = [
			"############",
			"#..a...r...#",
			"#P.....r..d#",
			"#......r...#",
			"#......r..E#",
			"#..........#",
			"############",
		]},
	{name = "EXT-43 · 候潮", tools = [], tip = "闸口跟着潮汐开合：闭着的时候，货会在闸前排成一列等。让箱子去排队——或者踩那口井，时间就听你的。",
		map = [
			"############",
			"#..........#",
			"#P.BfffpfSG#",
			"#..........#",
			"#....q.....#",
			"############",
		]},
	{name = "EXT-44 · 晶运", tools = ["ice"], tip = "冰晶推上带子就不会碎——它会一路驶到带子尽头再开花。碎成的水冻上，就是你在对岸架起的桥。",
		map = [
			"############",
			"#.....O....#",
			"#P.xfffO..G#",
			"#.....O....#",
			"#.....O....#",
			"#.....O....#",
			"############",
		]},
	{name = "EXT-45 · 潮渡", tools = [], tip = "潮滩横在带道上：闭窗时货会在滩前排成一列等，开窗的节拍一到就自动渡滩。货上了潮格可别耽搁——潮水不等人。",
		map = [
			"############",
			"#..........#",
			"#P.BffjffSG#",
			"#..........#",
			"#.........G#",
			"#..........#",
			"############",
		]},
	{name = "EXT-46 · 焚藤", tools = ["fire"], tip = "藤蔓挡得住货，挡不住人，更挡不住火。站上藤柱、借好朝向，烧穿两个洞——箱和铁各走各的道。烧掉的地方长不回来，可别乱点。",
		map = [
			"############",
			"#....l.....#",
			"#P.B.l..S.G#",
			"#..I.l..W..#",
			"#....l.....#",
			"#....l.....#",
			"############",
		]},
	{name = "EXT-47 · 引晶", tools = ["magnet", "ice"], tip = "冰晶缩在石龛里，推是推不动的——但磁石的视线能穿过去。一格一格把它引出来，送到坑边推进去，冻住，过。",
		map = [
			"############",
			"#..........#",
			"#P.OOOOOO.G#",
			"#.......x###",
			"#.......#..#",
			"#..........#",
			"############",
		]},
	{name = "EXT-48 · 潮轨", tools = ["ice"], tip = "暖轨车顺着轨道碾过来，什么冰都给你化了。潮格是它的命门：引它上潮格，踩井翻相——潮水一涨，车就没了。",
		map = [
			"############",
			"#..........#",
			"#P...~~~ucG#",
			"#.....q....#",
			"#..........#",
			"#..........#",
			"############",
		]},
	{name = "EXT-49 · 送货门", tools = [], tip = "成对的门这回也收货。两箱货都得进门——第二箱进门时那边已被占，它只能落在门旁边……门旁边是什么来着？",
		map = [
			"############",
			"#.G.....~~.#",
			"#P.B.B.XSY##",
			"#......~~~.#",
			"#..........#",
			"#..........#",
			"############",
		]},
	{name = "EXT-50 · 双踩", tools = [], tip = "这块板认两次：踩一次只是打个照面，得离开再回来（或让箱子先躺上去、你再站上去）才算数。停着不动的箱子，可开不了门。",
		map = [
			"############",
			"#..........#",
			"#P..B.s.G..#",
			"#..........#",
			"#..........#",
			"#..........#",
			"############",
		]},
	{name = "EXT-51 · 潮磨", tools = ["ice"], tip = "潮格开窗时把冰晶推上去——潮水一涨，晶就被磨成了水，潮格也从此成了水池。冻住它，河就过了。",
		map = [
			"############",
			"#..........#",
			"#.Pxu...S.G#",
			"#.B........#",
			"#..........#",
			"#..........#",
			"############",
		]},
	{name = "EXT-52 · 连碎", tools = ["ice"], tip = "冰晶碎的时候，挨着它的晶也会应声而碎。坑两边的两块晶，一推双碎——分着推，第二块永远堵在路上。",
		map = [
			"############",
			"#..........#",
			"#P..xOx.G..#",
			"#..........#",
			"#..........#",
			"#..........#",
			"############",
		]},
	{name = "EXT-53 · 弹晶", tools = ["ice"], tip = "弹射垫这回弹的是冰晶——一推上垫，它就飞过头顶落在两格之外，碎成一汪水。冻住，河就过了。",
		map = [
			"############",
			"#..........#",
			"#P.xk.O..G.#",
			"#..........#",
			"#..........#",
			"#..........#",
			"############",
		]},
	{name = "EXT-54 · 滑晶", tools = ["ice"], tip = "冰道这回载的是冰晶——一推上冰面就滑到头，坠进尽头的坑里化成一汪水。冻住，河就过了。",
		map = [
			"############",
			"#..........#",
			"#P.xiiiiO.G#",
			"#..........#",
			"#..........#",
			"#..........#",
			"############",
		]},
	{name = "EXT-55 · 车碾板", tools = [], tip = "暖轨车这回认板了——碾过双踩板算一次踩占，往返再碾就咬合。你站在轨道尽头，就是它的折返点。",
		map = [
			"############",
			"#..........#",
			"#P..s...c..#",
			"#..........#",
			"#........G.#",
			"#..........#",
			"############",
		]},
	{name = "EXT-56 · 车越堑", tools = [], tip = "轨道断了？垫子会把巡轨车弹过断口——它落在对岸正好碾上双踩板。你站在轨尾，就是它的折返点。",
		map = [
			"############",
			"#..........#",
			"#Ps.k....c.#",
			"#..........#",
			"#........G.#",
			"#..........#",
			"############",
		]},
	{name = "EXT-57 · 晶潮渡", tools = ["ice"], tip = "把冰晶推上带子，它会自己驶进潮滩——潮一涨，晶就被磨成了水，滩也从此成了水池。冻住，搭着带子过河。",
		map = [
			"############",
			"#.....#....#",
			"#P.xffu...G#",
			"#.....#....#",
			"#..........#",
			"#..........#",
			"############",
		]},
	{name = "EXT-58 · 桥渡", tools = [], phase_offset = 2.0, tip = "相位桥按拍子显形——重铁自己走不动，但带子会驮着它候窗、过桥、压住对岸的重压板。算准拍子，河就是路。",
		map = [
			"############",
			"#.....#....#",
			"#PIfffwffWG#",
			"#.....#....#",
			"#..........#",
			"#..........#",
			"############",
		]},
	{name = "EXT-59 · 候闸", tools = [], phase_offset = 0.0, tip = "潮闸只给车留了缝——它候着窗、过闸、稳稳压住对岸的重压板。你走你的路，门它来开。",
		map = [
			"############",
			"#..........#",
			"#P.c...pW.G#",
			"#..........#",
			"#..........#",
			"#..........#",
			"############",
		]},]


var state := "play"           # play / final
var room_idx := 0
# 七字段遥测：字段口径与旧版一致——object_move 不含沉水造路分支；melt 只计工具融冰；
# switch_on 是"门由关到开"的边沿计数（仅成功 move 后检测），不是每块压力板的导通次数。
var tele := {tool_use = 0, object_move = 0, freeze = 0, melt = 0, burn = 0, switch_on = 0, room5_complete = 0}
var solution_seq := []       # 本房动作序列 ["move:right", "push:box:water", "tool:ice:right", ...]
var family := ""             # 当前房 solution family：melt_route / magnet_iron / box_bridge / freeze_route / plain
var family_by_room := {}     # room_idx -> 首次通关归类
var gate_was_open := false
var grid: Array = []          # 长度 ROOM_W*ROOM_H：floor/wall/water/bridge/pit/fill/ice/gate
var player := {x = 1, y = 1}
var facing := "right"         # 仅成功 move 更新；工具不改变面向
var objects: Array = []       # {id, type=box/iron/switch/torch, x, y}；id 在本房内稳定，表现层用 id 绑定节点
var tools: Array = []
var steps := 0                # 成功 move 计数；工具与非法输入不计数
var gate_pos := {x = -1, y = -1}
var melt_queue: Array = []    # {x, y, left} 融化倒计时
var phase_clock: float = 0.0  # EXT-13 相位门时钟（advance_time 累计；load_room 归零）
var vent_clock: float = 0.0   # EXT-17 间歇泉相位（advance_time 累计；load_room 归零）
var vents: Array = []         # EXT-17 泉口坐标（Vector2i；_load_map 收集，喷发时融化四邻冰）
var cold_vents: Array = []    # EXT-19 寒泉坐标（Vector2i；半周期冻结四邻水）
var cold_fired := false       # EXT-19 本周期寒泉已喷标记（过整周期复位）
var phase_bridges: Array = [] # EXT-24 相位桥坐标（Vector2i；开窗可走/可推落点，闭窗结算桥面）
var link_slots: Array = []    # EXT-27 联动桥位坐标（Vector2i；联动开关全压住时通行）
var tide_cells: Array = []    # EXT-31 潮汐格坐标（Vector2i；大潮周期前半露出后半淹没）
var tide_late_cells: Array = []  # EXT-33 反相潮汐格坐标（开窗 [2,6)，与 u 错相 2 秒）
var cart_clock: float = 0.0   # EXT-35 暖轨车相位（advance_time 累计；load_room 归零）
var cart_dir := 1             # EXT-35 巡轨方向：1=东起步 -1=西（撞阻反转）
var has_key := false          # EXT-36 钥匙信物（踩 key_item 拾取；开 locked_gate 用；load_room 归零）
var has_silver := false       # EXT-42 银钥信物（踩 key_silver 拾取；穿 locked_gate_s 用；load_room 归零）
var belt_clock: float = 0.0   # EXT-40 输送带相位（advance_time 累计；load_room 归零）
var belts: Array = []         # EXT-40 带格坐标（Vector2i；行-列序遍历保证确定性）
var rooms_cleared := 0

var _next_object_id := 0
var _events: Array = []       # 事件批次，drain_events() 读取后清空；切房不清（room_clear 事件必须能被读到）


func _init() -> void:
	load_room(0)


# ---------------- 房间装载与生命周期 ----------------

func load_room(i: int) -> void:
	if i < 0 or i >= _total_rooms():
		return
	room_idx = i
	var R: Dictionary = ROOMS[i] if i < ROOMS.size() else ROOMS_EXT[i - ROOMS.size()]
	_load_map((R.tools as Array).duplicate(), R.map)
	# EXT-58 桥渡：房间可选相位偏移（地图字段 phase_offset，秒）——桥/门/潮的初始
	# 相位整体平移（t=0 即闭窗的房间由此表达；不设默认 0）
	phase_clock = float(R.get("phase_offset", 0.0))


func _total_rooms() -> int:
	return ROOMS.size() + ROOMS_EXT.size()


## 房名跨主表/扩展表（HUD/事件用；越界返回空串）
func room_name(i: int) -> String:
	if i < 0 or i >= _total_rooms():
		return ""
	return String(ROOMS[i].name) if i < ROOMS.size() else String(ROOMS_EXT[i - ROOMS.size()].name)


## 旧 _restart 等价：回房1，但 tele/steps/rooms_cleared/family_by_room 保留（差异6 兼容基线）
func restart() -> void:
	load_room(0)


## 新样本入口（旧版没有）：整局重开 = 全清遥测/步数/家族/已通过数 + 回房1，真人样本不得混局
func reset_sample() -> void:
	tele = {tool_use = 0, object_move = 0, freeze = 0, melt = 0, burn = 0, switch_on = 0, room5_complete = 0}
	steps = 0
	rooms_cleared = 0
	family_by_room = {}
	load_room(0)


## ASCII 地图解析（ROOMS 表与测试构造共用；只搬运旧 load_room 的解析逻辑，不加规则）
func _load_map(room_tools: Array, rows: Array) -> void:
	grid = []
	objects = []
	melt_queue = []
	phase_clock = 0.0
	vent_clock = 0.0
	vents = []
	cold_vents = []
	cold_fired = false
	cart_clock = 0.0
	cart_dir = 1
	has_key = false
	has_silver = false
	belt_clock = 0.0
	belts = []
	phase_bridges = []
	link_slots = []
	tide_cells = []
	tide_late_cells = []
	gate_pos = {x = -1, y = -1}
	solution_seq = []
	family = ""
	gate_was_open = false
	_next_object_id = 0
	var rows_y: int = mini(rows.size(), ROOM_H)
	for y in ROOM_H:
		var row: String = rows[y] if y < rows_y else "############"
		for x in ROOM_W:
			var ch := row[x]
			var tile := "floor"
			match ch:
				"#":
					tile = "wall"
				"~":
					tile = "water"
				"O":
					tile = "pit"
				"C":
					tile = "thin_ice"
				"A":
					# EXT-7：永冻冰地形（地图直出的 ice，不经 F 冻结；可走、可推落点）
					tile = "ice"
				">":
					tile = "oneway_e"
				"<":
					tile = "oneway_w"
				"^":
					tile = "oneway_n"
				"v":
					tile = "oneway_s"
				"X":
					# EXT-9：传送对格（入门即传送到对格；物体不传送、按平地落点）
					tile = "portal_x"
				"Y":
					tile = "portal_y"
				"K":
					# EXT-11：裂纹墙——实体阻挡同墙，G 火把可烧毁成 floor（唯一通路）
					tile = "cracked_wall"
				"i":
					# EXT-12：滑冰格——入门后顺入向连滑（遇阻挡/非滑格即停；物体不滑）
					tile = "slide_ice"
				"Z":
					# EXT-13：相位门——advance_time 驱动的定时开合（开 PHASE_OPEN_TIME / 周期 PHASE_PERIOD）
					tile = "phase_gate"
				"z":
					# EXT-15：反相相位门——与 Z 互补开合（Z 开它关、Z 关它开），节奏走廊的另一半
					tile = "phase_gate_inv"
				"J":
					# EXT-14：弹簧垫——入门后定距二格跳（越过中间格；跳点不可达则停在垫上；物体不跳）
					tile = "spring"
				"V":
					# EXT-17：间歇泉——周期性热源地形（不可走/不可推），每 VENT_PERIOD 融化四邻冰
					tile = "vent"
					vents.append(Vector2i(x, y))
				"Q":
					# EXT-19：寒泉——周期性冷源地形（不可走/不可推），每 VENT_PERIOD 冻结四邻水（与热泉半周期错相）
					tile = "cold_vent"
					cold_vents.append(Vector2i(x, y))
				"D":
					# EXT-20：脆壁——碰即碎成 floor（隐藏通路；铁/箱推入同样触发）
					tile = "crumble"
				"U":
					# EXT-22：暗缝——墙上窄缝，只有玩家可通行（箱/铁推入拒绝、滑行不入、
					# 磁拉落点拒绝；缝不挡磁拉视线、不碎不重生）
					tile = "slot"
				"o":
					# EXT-23：疑路——伪装成地板的暗坑：踩上即露馅成 pit（本步拒绝）；
					# 重物推上则露馅并按既有 pit 沉底填坑语义（滑行不入、磁拉落点拒绝）
					tile = "hidden_pit"
				"w":
					# EXT-24：相位桥——与相位钟同拍的地形桥（开窗 [0,PHASE_OPEN_TIME) 可走/可推
					# 落点，闭窗为水；桥上遇闭窗玩家弹回、重物按融化三分支先例移除）
					tile = "phase_bridge"
					phase_bridges.append(Vector2i(x, y))
				"k":
					# EXT-26：弹射垫——box/iron 被推上垫沿推向定距弹 2 格（跳点白名单落点、
					# 中间格无视可越水；被挡则留在垫上）；玩家可正常通行，垫不弹人
					tile = "launcher"
				"y":
					# EXT-34：推塌桩——只认推力的假墙：玩家行走撞上被弹回；box/iron 被推上
					# 才撞塌成永久 floor（与 EXT-20 脆壁"一碰就碎"互为镜像）
					tile = "push_stub"
				"c":
					# EXT-35：暖轨车出生格——自主巡轨热源（对象，沿本行东西往返 1 秒一步）：
					# 轨上木箱按火语义焚烧、轨下冰面熔化成水；人/箱/铁不可推不可撞。
					# EXT-55 车碾板：压板导通——普通/反相板停上占位判定、双踩板碾过计数
					tile = "floor"
					objects.append(_new_object("cart", x, y))
				"d":
					# EXT-36：钥匙格——玩家踩上即拾取（tile 变 floor + has_key）；
					# box/iron 推落点非法（防止货物盖住钥匙造成软锁）
					tile = "key_item"
				"E":
					# EXT-36：锁门——只认钥匙的第二种门（无 key 拒行、有 key 进门即过关，
					# 与压力板门完全解耦；推落点非法）
					tile = "locked_gate"
				"l":
					# EXT-37：藤蔓墙——首个按对象区分的地形：玩家可攀越通行（行走/站立同
					# 地板），货物不可穿（推落点非法）、磁拉视线截断、车轨与弹射落点拒绝
					tile = "ivy"
				"x":
					# EXT-38：冰晶出生格——可推一次的自置水源（对象）：被推落点整格化为
					# water（可 F 冻成桥）；入 _solid_at（撞上即推、车反弹、不压板、
					# EXT-47 起磁认晶——可被磁拉逐格拉出死角，落点白名单与铁同）
					tile = "floor"
					objects.append(_new_object("crystal", x, y))
				"q":
					# EXT-39：换相井——踩上即相位 +4 秒：潮汐 u/j、相位门/桥即时翻转
					# （沿结算同构 advance_time；井面不作推落点，只认脚步）
					tile = "tide_well"
				"f":
					# EXT-40：东行输送带——每 1 秒节拍把带上 box/iron/玩家沿向搬一格
					# （落点不合法原地等待；箱先动、人补位；推箱落点白名单含带=可上货）
					tile = "belt_e"
					belts.append(Vector2i(x, y))
				"h":
					tile = "belt_w"
					belts.append(Vector2i(x, y))
				"m":
					# EXT-41：南行输送带——经纬补全：f/h/m/t 首尾相接即成转向器
					tile = "belt_s"
					belts.append(Vector2i(x, y))
				"t":
					tile = "belt_n"
					belts.append(Vector2i(x, y))
				"a":
					# EXT-42：银钥格——踩上即拾取（tile 变 floor + has_silver，独立于金钥旗标）；
					# box/iron 推落点非法（防盖钥软锁，与金钥同式）
					tile = "key_silver"
				"r":
					# EXT-42：银门——有银钥即穿行的通道门（不触发过关；推落点非法）
					tile = "locked_gate_s"
				"p":
					# EXT-43：潮闸——潮相位驱动的通道闸：开窗 [4,8) 时人/推箱/带运三通道
					# 皆放行，闭窗三路皆拒（带上货物在闸前排成一列候潮；踩井可提前开闸）
					tile = "tide_gate"
				"e":
					# EXT-27：联动桥位——压住全部联动开关（'b'）时如填土可走/可推落点，
					# 松开即断（惰性结算：桥上玩家弹回、重物按融化三分支先例移除）
					tile = "link_slot"
					link_slots.append(Vector2i(x, y))
				"g":
					# EXT-29：油道——box 被推上会顺向滑行（iron 不滑）、玩家踏上同滑；
					# 与冰道互不接力，遇实体/阻挡即停
					tile = "grease"
				"u":
					# EXT-31：潮汐格——8 秒大潮周期（相位钟 2:1 倍频）：前半 [0,4) 露出湿泥
					# 可走/可推落点，后半淹没为水；淹没瞬间惰性结算（玩家弹回/重物移除）
					tile = "tide_cell"
					tide_cells.append(Vector2i(x, y))
				"j":
					# EXT-33：反相潮汐格——开窗 [2,6)（与 u 错相 2 秒）：换乘窗内两滩同露，
					# 其余时间一格露一格淹；淹没惰性结算与 u 同构
					tile = "tide_late"
					tide_late_cells.append(Vector2i(x, y))
				"R":
					tile = "reset_stone"
				"G":
					tile = "gate"
					gate_pos = {x = x, y = y}
			grid.append(tile)
			match ch:
				"P":
					player = {x = x, y = y}
				"B":
					objects.append(_new_object("box", x, y))
				"I":
					objects.append(_new_object("iron", x, y))
				"M":
					objects.append(_new_object("torch_m", x, y))
				"T":
					objects.append(_new_object("torch", x, y))
				"S":
					objects.append(_new_object("switch", x, y))
				"N":
					objects.append(_new_object("switch_not", x, y))
				"W":
					# EXT-10：重压板——仅 iron 压住导通（玩家/box 不算）
					objects.append(_new_object("switch_heavy", x, y))
				"L":
					# EXT-18：自锁踏板——首次被任何重量踩上即永久锁定（latched=true）
					objects.append(_new_object("switch_latch", x, y))
				"b":
					# EXT-27：联动开关——占用型压板，但压住的不是门而是联动桥位（'e' 格）
					objects.append(_new_object("switch_link", x, y))
				"s":
					# EXT-50：双踩板——同板累计 2 次踩占（人/箱/铁每次"进入"计一次）
					# 才永久导通（latch）；单次踩板 EXT-18 自锁板的计数版
					objects.append(_new_object("switch_double", x, y))
				"n":
					# EXT-4 复合格：反相板 + 其上的箱（同格两对象）
					objects.append(_new_object("switch_not", x, y))
					objects.append(_new_object("box", x, y))
	tools = room_tools
	facing = "right"
	state = "play"


func _new_object(otype: String, x: int, y: int) -> Dictionary:
	var od := {id = _next_object_id, type = otype, x = x, y = y}
	if otype == "switch_latch":
		od.latched = false
	if otype == "switch_double":
		od.count = 0
		od.latched = false
	_next_object_id += 1
	return od


## 按 id 查对象（表现层绑定节点用；不提供数组下标关联——旧 pushed_idx 已废弃）
func object_by_id(id: int) -> Dictionary:
	for o in objects:
		if int(o.id) == id:
			return o
	return {}


## 事件批次：核心不依赖事件，读后即清
func drain_events() -> Array:
	var out := _events
	_events = []
	return out


# ---------------- 查询 ----------------

func _idx(x: int, y: int) -> int:
	return y * ROOM_W + x


func _in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < ROOM_W and y >= 0 and y < ROOM_H


func _tile(x: int, y: int) -> String:
	return String(grid[_idx(x, y)])


## EXT-8 单向格：tile 名 → 允许的入向（非单向格返回空串）。出向不限；玩家与推物落点同约束。
func _oneway_allow(t: String) -> String:
	if t == "oneway_e":
		return "right"
	if t == "oneway_w":
		return "left"
	if t == "oneway_n":
		return "up"
	if t == "oneway_s":
		return "down"
	return ""


## EXT-9 传送对格：tile 名 → 对格 tile 名（非传送格返回空串）。
func _portal_pair(t: String) -> String:
	if t == "portal_x":
		return "portal_y"
	if t == "portal_y":
		return "portal_x"
	return ""


## EXT-12：滑行可入格——普通可走地形 + 排除薄冰（碎裂不与滑行叠加）、裂纹墙（烧毁语义）、
## 传送/单向/重置石（入口语义不在滑行中触发，组合留待评审）；实体占格不可入（铁墩=刹车）。
func _slide_enterable(x: int, y: int) -> bool:
	var t := _tile(x, y)
	if t == "wall" or t == "water" or t == "pit" or t == "thin_ice" or t == "cracked_wall" \
			or t == "portal_x" or t == "portal_y" or t == "reset_stone" or t == "phase_gate" \
			or t == "phase_gate_inv" or t == "cold_vent" or t == "crumble" or t == "slot" \
			or t == "hidden_pit" or t == "phase_bridge" or t == "link_slot" or t == "tide_cell" \
			or t == "tide_late" or t == "push_stub" or t == "ivy" or t == "key_silver" \
			or t == "locked_gate_s" or t.begins_with("oneway_"):
		return false
	if t == "gate" and not gate_open():
		return false
	if t == "locked_gate" and not has_key:
		return false
	if t == "locked_gate_s" and not has_silver:
		return false
	if t == "tide_gate" and not tide_gate_open():
		# EXT-43 潮闸：闭窗不可站（跳跃落点排除）；开窗同普通通道格
		return false
	return _solid_at(x, y).is_empty()


## EXT-13：相位门开合判定——时钟落在本周期开启窗（[0, PHASE_OPEN_TIME)）即开。
## 确定性：advance_time 累计 phase_clock，逻辑测试手动推 dt 锁相；表现层每帧真实走表。
## EXT-15：反相门（phase_gate_inv）与其精确互补——Z 开它关、Z 关它开。
func phase_gate_open() -> bool:
	return fmod(phase_clock, PHASE_PERIOD) < PHASE_OPEN_TIME


func phase_gate_inv_open() -> bool:
	return not phase_gate_open()


## EXT-14：弹簧垫跳点——普通地形（floor/ice/bridge/fill/spring）+ 无实体；
## EXT-19 寒泉冻结：所有寒泉四邻的水冻成冰（热泉 V 的对偶；喷发时机与热泉错半相——
## 同一格被 Q/V 夹住即周期性冰水交替）。仅冻 water，既有 ice/桥面不受影响。
func _freeze_cold_vents() -> void:
	for q_v in cold_vents:
		var q: Vector2i = q_v
		for off_v in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var off: Vector2i = off_v
			var ox: int = q.x + off.x
			var oy: int = q.y + off.y
			if _in_bounds(ox, oy) and _tile(ox, oy) == "water":
				_set_tile(ox, oy, "ice")
				_events.append({type = "freeze", at = Vector2i(ox, oy), msg = "寒泉：水面冻成了冰"})


## EXT-17 间歇泉喷发：所有泉口四邻的冰融化一次（复用 _melt_ice_tile 三分支——
## 冰上箱/铁沉落、玩家弹回最近站立点；非冰格静默跳过）。advance_time 过周期点时调用。
func _fire_vents() -> void:
	for v_v in vents:
		var v: Vector2i = v_v
		for off_v in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var off: Vector2i = off_v
			var ox: int = v.x + off.x
			var oy: int = v.y + off.y
			if _in_bounds(ox, oy) and _tile(ox, oy) == "ice":
				_melt_ice_tile(ox, oy)


## spring 可作落点但不连锁（跳是入格触发，落定即止）；其余特殊格排除（组合留待评审）。
func _hop_enterable(x: int, y: int) -> bool:
	var t := _tile(x, y)
	if t != "floor" and t != "ice" and t != "bridge" and t != "fill" and t != "spring":
		return false
	return _solid_at(x, y).is_empty()


## EXT-9：扫描全格找对格坐标（84 格线性扫描，确定性优先；对格必存在——解析成对出图）。
func _portal_find(dest_tile: String) -> Vector2i:
	for y in ROOM_H:
		for x in ROOM_W:
			if _tile(x, y) == dest_tile:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _set_tile(x: int, y: int, t: String) -> void:
	grid[_idx(x, y)] = t


## 该格上的实体（box/iron/torch/torch_m）；开关是压力板不算实体
func _solid_at(x: int, y: int) -> Dictionary:
	for o in objects:
		var od: Dictionary = o
		var t := String(od.type)
		if (t == "box" or t == "iron" or t == "torch" or t == "torch_m" or t == "cart" or t == "crystal") and int(od.x) == x and int(od.y) == y:
			return od
	return {}


## 普通压力板导通判定（占用型）：玩家或 box/iron 压住导通；torch/torch_m 不算
func _switch_pressed(od: Dictionary) -> bool:
	var sx: int = int(od.x)
	var sy: int = int(od.y)
	# EXT-55 车碾板：占位判定统一走 _occupant_on（人/箱/铁/车）——车停板上=压住
	return _occupant_on(sx, sy)


## EXT-38：开关板所在格判定（冰晶碎水不可淹没任何压力板——板是贴地家具，泡水即坏语义）
func _switch_object_at(x: int, y: int) -> bool:
	for o in objects:
		var od: Dictionary = o
		if String(od.type).begins_with("switch") and int(od.x) == x and int(od.y) == y:
			return true
	return false


## EXT-27 联桥：全部联动开关被压住（人/箱/铁占用）时桥位通行；无联动开关视为断。
func _link_pressed() -> bool:
	var found := false
	for o in objects:
		var od: Dictionary = o
		if String(od.type) == "switch_link":
			found = true
			if not _switch_pressed(od):
				return false
	return found


## EXT-31 潮汐：8 秒大潮周期（相位钟 2:1 倍频）——前半 [0,4) 露出湿泥可走，后半淹没为水。
func tide_open() -> bool:
	return fmod(phase_clock, PHASE_PERIOD * 2.0) < PHASE_PERIOD


## EXT-33 反相潮汐：开窗 [2,6)——与 u 的 [0,4) 错相 2 秒，重叠 [2,4) 为换乘窗。
func tide_late_open() -> bool:
	return fmod(phase_clock + PHASE_PERIOD * 1.5, PHASE_PERIOD * 2.0) < PHASE_PERIOD


## EXT-43 潮闸：开窗 [4,8) mod 8——与 u 互补的后半拍（装载即闭，强迫候潮或踩井换相）。
func tide_gate_open() -> bool:
	return fmod(phase_clock, PHASE_PERIOD * 2.0) >= PHASE_PERIOD


## EXT-31/33 潮汐淹没惰性结算：格上重物失去支撑移除、玩家退回最近可站立格
## （融化三分支先例；地形不变仍是潮格，回露/重潮即复通）。
func _close_tide_cells(cells: Array) -> void:
	for tc_v in cells.duplicate():
		var tc: Vector2i = tc_v
		var occupant := _solid_at(int(tc.x), int(tc.y))
		if not occupant.is_empty():
			var ot := String(occupant.type)
			objects.erase(occupant)
			if ot == "crystal":
				# EXT-51 潮磨：潮没的冰晶把所在潮格碾成永久水池（晶消散、潮格除名——
				# 后续开/闭窗不再 toggles 此格；F 可冻成永久冰桥）
				_set_tile(int(tc.x), int(tc.y), "water")
				cells.erase(tc_v)
				_events.append({type = "shatter", id = int(occupant.id), at = Vector2i(int(tc.x), int(tc.y)),
					msg = "潮磨：潮水把冰晶碾成了水，潮格从此成了水池"})
				continue
			_events.append({type = "tide_break", at = Vector2i(int(tc.x), int(tc.y)), occupant = ot,
				id = int(occupant.id), msg = "潮水淹没了一切：" + ot + "失去了支撑"})
			continue
		if int(player.x) == int(tc.x) and int(player.y) == int(tc.y):
			var spot := _nearest_standing_spot(int(tc.x), int(tc.y))
			var ev := {type = "tide_break", at = Vector2i(int(tc.x), int(tc.y)), occupant = "player",
				msg = "潮水涨了，你退回了旁边的地面"}
			if not spot.is_empty():
				ev.player_from = Vector2i(int(player.x), int(player.y))
				player = {x = int(spot.x), y = int(spot.y)}
				ev.player_to = Vector2i(int(spot.x), int(spot.y))
			_events.append(ev)


## EXT-2 反相压力板（switch_not）：空置导通，被玩家/box/iron 占据断开（与普通板反逻辑）。
## EXT-10 重压板（switch_heavy）：仅 iron 压住导通——玩家/box 踩上不算（重量语义）。
func _plate_satisfied(od: Dictionary) -> bool:
	var t := String(od.get("type", "switch"))
	if t == "switch_not":
		return not _occupant_on(int(od.x), int(od.y))
	if t == "switch_heavy":
		return _iron_on(int(od.x), int(od.y))
	if t == "switch_latch":
		return bool(od.get("latched", false))
	if t == "switch_double":
		return bool(od.get("latched", false))
	return _switch_pressed(od)


## EXT-10：重压板专用——该格实体是否恰为 iron
func _iron_on(x: int, y: int) -> bool:
	var s := _solid_at(x, y)
	# EXT-59 候闸：重压板=重物板——铁或暖轨车压住导通（EXT-55 统一占位判定的延续：
	# 车=自走重物；玩家/box 仍不算）
	if s.is_empty():
		return false
	return String(s.type) == "iron" or String(s.type) == "cart"


func _occupant_on(x: int, y: int) -> bool:
	if int(player.x) == x and int(player.y) == y:
		return true
	var s := _solid_at(x, y)
	if s.is_empty():
		return false
	# EXT-55 车碾板：暖轨车=重量占位者——普通板停上导通、反相板停上压制（离格逐拍重估）
	return String(s.type) == "box" or String(s.type) == "iron" or String(s.type) == "cart"


## 门开 = 全部板各自满足（普通板压住、反相板空置）；无板房间门常开
func gate_open() -> bool:
	var all_on := true
	var found := false
	for o in objects:
		var od: Dictionary = o
		var t := String(od.type)
		if t == "switch" or t == "switch_not" or t == "switch_heavy" or t == "switch_latch" \
				or t == "switch_double":
			found = true
			if not _plate_satisfied(od):
				all_on = false
	if not found:
		return true
	return all_on


func is_win() -> bool:
	if state == "final":
		return true
	if int(gate_pos.x) < 0:
		return false
	return int(player.x) == int(gate_pos.x) and int(player.y) == int(gate_pos.y) and gate_open()


# ---------------- 核心动作：移动 + 推物 ----------------

func try_move(dir: String) -> bool:
	# EXT-27 联桥：支撑惰性结算（占用变化后的断桥在此刻落地——玩家弹回/重物移除）
	_eval_link_bridges()
	if state != "play" or not DIR_VECS.has(dir):
		return false
	var d: Vector2i = DIR_VECS[dir]
	var px: int = int(player.x)
	var py: int = int(player.y)
	var nx: int = px + d.x
	var ny: int = py + d.y
	if not _in_bounds(nx, ny):
		return false
	var tile := _tile(nx, ny)
	if tile == "wall" or tile == "cracked_wall":
		return false
	var target := _solid_at(nx, ny)
	if not target.is_empty() and String(target.type) == "switch_link":
		# EXT-27：联动开关不阻挡玩家——踩上即压住（占用型）；配合下方"switch_link 不可推"
		target = {}
	if not target.is_empty():
		var ttype := String(target.type)
		if ttype == "torch" or ttype == "switch_link" or ttype == "cart":
			# 火把与联动开关是家具：不可推（联动开关被推离会瞬断桥面，语义上禁止）；
			# 暖轨车是自主热源（EXT-35）：不可推、不可撞——撞上弹回，轨上只得绕行
			return false
		# 推动判定：落点必须空且表面允许
		var bx: int = nx + d.x
		var by: int = ny + d.y
		if not _in_bounds(bx, by):
			return false
		var btile := _tile(bx, by)
		# EXT-23 疑路：重物推上暗坑 → 露馅成 pit（复用下方既有沉底填坑语义；家族归 box_bridge）
		if btile == "hidden_pit":
			_set_tile(bx, by, "pit")
			_events.append({type = "reveal", at = Vector2i(bx, by)})
			btile = "pit"
		if not _solid_at(bx, by).is_empty() or btile == "wall" or btile == "ivy" or btile == "gate" \
				or btile == "locked_gate" or btile == "locked_gate_s" or btile == "key_item" \
				or btile == "key_silver" or btile == "cracked_wall" \
				or (btile == "phase_gate" and not phase_gate_open()) \
				or (btile == "phase_gate_inv" and not phase_gate_inv_open()) or btile == "vent" or btile == "cold_vent" \
				or btile == "slot" \
				or (btile == "phase_bridge" and not phase_gate_open()) \
				or (btile == "link_slot" and not _link_pressed()) \
				or (btile == "tide_cell" and not tide_open()) \
				or (btile == "tide_late" and not tide_late_open()) \
				or (btile == "tide_gate" and not tide_gate_open()):
			return false
		# EXT-20 脆壁：被推即碎（永久 floor），推入照常落位（btile 同步改 floor，
		# 否则下方落点白名单会把 crumble 当未知道格走 oneway 拒绝分支）
		if btile == "crumble":
			_set_tile(bx, by, "floor")
			btile = "floor"
			_events.append({type = "crumble", at = Vector2i(bx, by)})
		# EXT-34 推塌桩：只认推力——box/iron 被推上桩体才撞塌成永久 floor
		# （玩家行走撞上被弹回；与 EXT-20 脆壁"一碰就碎"互为镜像）
		if btile == "push_stub":
			_set_tile(bx, by, "floor")
			btile = "floor"
			_events.append({type = "stub_break", at = Vector2i(bx, by)})
		# EXT-49 送货门：推物入传送门 → 物传至对格（"物传人留"——推箱人不入门不前进，
		# 防人被连锁传走）；对格被占/即玩家格 → 退最近可立位（潮没弹回同款逐圈搜索，
		# 含占用复检——被推物自身占的门格不算可立）；全无空位/对格不存在 → 整步拒绝。
		# 晶同款可传（门非水——推晶入门不碎）。序列串不进分类器（差异5 冻结）。
		if (btile == "portal_x" or btile == "portal_y") \
				and (ttype == "box" or ttype == "crystal"):
			var dest_cell: Vector2i = _portal_find(_portal_pair(btile))
			var landing := {}
			if dest_cell.x >= 0 and _solid_at(int(dest_cell.x), int(dest_cell.y)).is_empty() \
					and not (int(player.x) == int(dest_cell.x) and int(player.y) == int(dest_cell.y)):
				landing = {x = int(dest_cell.x), y = int(dest_cell.y)}
			elif dest_cell.x >= 0:
				var spot := _nearest_standing_spot(int(dest_cell.x), int(dest_cell.y))
				if not spot.is_empty() and _solid_at(int(spot.x), int(spot.y)).is_empty() \
						and not (int(player.x) == int(spot.x) and int(player.y) == int(spot.y)):
					landing = spot
			if landing.is_empty():
				return false
			target.x = int(landing.x)
			target.y = int(landing.y)
			_count_double_at(int(landing.x), int(landing.y))
			tele.object_move += 1
			solution_seq.append("push:" + ttype + ":portal")
			_events.append({type = "warp", id = int(target.id), otype = ttype,
				from = Vector2i(nx, ny), to = Vector2i(int(landing.x), int(landing.y)),
				msg = "送货门：货物被门吞了进去，出现在了门的另一边"})
			steps += 1
			return true
		# EXT-44 晶运：推晶落带不碎——上带随带行驶（正常推入；带尾出带才碎，见 _belt_step）
		if ttype == "crystal" \
				and (btile == "belt_e" or btile == "belt_w" or btile == "belt_s" or btile == "belt_n"):
			if _switch_object_at(bx, by):
				return false
			target.x = bx
			target.y = by
			tele.object_move += 1
			solution_seq.append("push:crystal")
			_events.append({type = "push", id = int(target.id), otype = ttype,
				from = Vector2i(nx, ny), to = Vector2i(bx, by)})
		# EXT-53 弹晶：晶推上弹射垫沿推向弹 2 格、落点即碎成水（跨坑投水——
		# 落点白名单 floor/water/pit；落点越界/非白名单/被占/玩家格 → 整步拒绝，
		# 晶留原地不预碎；独立分支——垫上弹射不走 EXT-38 原位碎块）
		elif ttype == "crystal" and btile == "launcher":
			var lx53: int = bx + d.x * 2
			var ly53: int = by + d.y * 2
			var ltile53: String = _tile(lx53, ly53) if _in_bounds(lx53, ly53) else "wall"
			if not _in_bounds(lx53, ly53) or not (ltile53 == "floor" or ltile53 == "pit" or ltile53 == "water") \
					or not _solid_at(lx53, ly53).is_empty() \
					or (int(player.x) == lx53 and int(player.y) == ly53):
				return false
			var launch_cid := int(target.id)
			objects.erase(target)
			_set_tile(lx53, ly53, "water")
			tele.object_move += 1
			solution_seq.append("push:crystal")
			_events.append({type = "launch", id = launch_cid, otype = ttype,
				at = Vector2i(bx, by), to = Vector2i(lx53, ly53),
				msg = "弹射垫：冰晶被弹向了两格之外"})
			_events.append({type = "shatter", id = launch_cid, at = Vector2i(lx53, ly53),
				msg = "冰晶在落点碎成一汪清水"})
		elif ttype == "crystal":
			# EXT-54 滑晶：晶推上冰道/油道沿向滑行——滑道延续（冰油互续），出道落点=
			# 滑道后第一格（普通可入格进入；水/坑可入=投水碎）；落点非法（墙/实体/
			# 薄冰/潮格…）则晶停末段滑道 → 下方白名单拒绝整步（晶不停滑道）
			if btile == "slide_ice" or btile == "grease":
				while true:
					var sx54: int = bx + d.x
					var sy54: int = by + d.y
					if not _in_bounds(sx54, sy54):
						break
					var st54: String = _tile(sx54, sy54)
					if st54 == "slide_ice" or st54 == "grease":
						bx = sx54
						by = sy54
						continue
					if _slide_enterable(sx54, sy54) or st54 == "water" or st54 == "pit":
						bx = sx54
						by = sy54
					break
				btile = _tile(bx, by)
			# EXT-38 冰晶：被推即碎——落点整格化为 water（自置水源，可 F 冻成桥）；
			# 落点白名单 floor/water/pit + 开窗潮格（EXT-51 潮磨：推晶入开窗潮格当场
			# 磨成水——潮格化为永久水池并从潮格数组除名；闭沿结算晶占位同款兜底），
			# 开关板所在格拒绝（板不可被淹没）；
			# 不增 object_move（沉水造路同口径——地形创造动词）；序列记 push:crystal
			if (btile != "floor" and btile != "water" and btile != "pit" \
					and not (btile == "tide_cell" and tide_open())) \
					or _switch_object_at(bx, by):
				return false
			var crystal_id := int(target.id)
			objects.erase(target)
			_set_tile(bx, by, "water")
			if btile == "tide_cell" or btile == "tide_late":
				# EXT-51 潮磨：晶在潮格上化水 → 潮格被磨掉（除名，后续不再 toggles）
				tide_cells.erase(Vector2i(bx, by))
				tide_late_cells.erase(Vector2i(bx, by))
			solution_seq.append("push:crystal")
			_events.append({type = "shatter", id = crystal_id, at = Vector2i(bx, by),
				msg = "冰晶碎了一地，化作一汪清水"})
			# EXT-52 连碎：碎裂波及四邻晶（连通分量全碎成水——逐环扩散，晶消散后
			# 不再连通天然终止；链碎的晶"死在自己格上"、各发 shatter、不写序列）
			var frontier: Array = [Vector2i(bx, by)]
			while not frontier.is_empty():
				var cc: Vector2i = frontier.pop_back()
				for off_v in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
					var off: Vector2i = off_v
					var nb: Vector2i = cc + off
					var nb_c := {}
					for o2 in objects:
						if String(o2.type) == "crystal" and int(o2.x) == int(nb.x) and int(o2.y) == int(nb.y):
							nb_c = o2
					if not nb_c.is_empty():
						objects.erase(nb_c)
						_set_tile(int(nb.x), int(nb.y), "water")
						tide_cells.erase(nb)
						tide_late_cells.erase(nb)
						_events.append({type = "shatter", id = int(nb_c.id), at = nb,
							msg = "连锁碎裂：邻晶应声而碎，化作一汪清水"})
						frontier.append(nb)
		elif btile == "water" or btile == "pit" or btile == "thin_ice":
			# EXT 机制：移动火把不入水/坑（推落点非法即拒绝），box/iron 保持差异1兼容基线；
			# EXT-3：薄冰承不住重物——推物落点为 thin_ice 一律拒绝
			if ttype == "torch_m" or btile == "thin_ice":
				return false
			# 差异1 兼容基线：box/iron 都沉、造 bridge/fill；不增 object_move；序列硬编码 push:box:*
			var sink_id := int(target.id)
			objects.erase(target)
			_set_tile(bx, by, "bridge" if btile == "water" else "fill")
			solution_seq.append("push:box:" + btile)
			_events.append({type = "sink", id = sink_id, otype = ttype, at = Vector2i(bx, by),
				becomes = "bridge" if btile == "water" else "fill",
				msg = "木箱沉了下去，变成了可以走的路面"})
		else:
			if btile != "floor" and btile != "ice" and btile != "reset_stone" \
					and btile != "portal_x" and btile != "portal_y" and btile != "spring" \
					and btile != "slide_ice" and btile != "phase_bridge" and btile != "launcher" \
					and btile != "grease" and btile != "belt_e" and btile != "belt_w" \
					and btile != "belt_s" and btile != "belt_n" \
					and btile != "tide_cell" and btile != "tide_late" and btile != "tide_gate":
				# （潮格/潮闸的闭窗态已在上方落点拒绝表拦下——此处放行=开窗可推上）
				# EXT-8 单向格作推落点：推入方向须与箭头一致（逆行推入拒绝）
				if _oneway_allow(btile) != dir:
					return false
			target.x = bx
			target.y = by
			# EXT-16：铁墩推上滑冰格会顺向滑行——仅 iron（金属）滑、box（木质）不滑；
			# 语义与玩家滑行一致：顺冰延续、出溜落到第一块非滑格（重压板等 floor 落点=正好压板）。
			# 整段仍计 1 次 push、事件 to=最终停点。
			if ttype == "iron" and _tile(bx, by) == "slide_ice":
				while _tile(bx, by) == "slide_ice":
					var isx: int = bx + d.x
					var isy: int = by + d.y
					if not _in_bounds(isx, isy) or not _slide_enterable(isx, isy):
						break
					bx = isx
					by = isy
				target.x = bx
				target.y = by
			# EXT-29 油道：box 推上油道会顺向滑行——仅 box（木质）滑、iron 不滑（与 EXT-16
			# 铁滑冰道互为镜像）；语义同上：顺油延续、落到第一块非油格。仍计 1 次 push。
			# 注意块序：油道滑行在弹射判定**之前**——滑行末段落上弹射垫会接力弹射（EXT-30 联运）。
			if ttype == "box" and _tile(bx, by) == "grease":
				while _tile(bx, by) == "grease":
					var gsx: int = bx + d.x
					var gsy: int = by + d.y
					if not _in_bounds(gsx, gsy) or not _slide_enterable(gsx, gsy):
						break
					bx = gsx
					by = gsy
				target.x = bx
				target.y = by
			# EXT-26 弹射垫：box/iron 落上垫（直接推上，或油道滑行末段接力）沿推向定距弹 2 格
			# （EXT-14 跳点白名单落点、中间格无视可越水；落点被挡则留在垫上）。仍计 1 次 push
			# （object_move 不加弹射），事件 to=弹射落点，另发 launch 事件。torch_m 推上垫走
			# 落点白名单外=拒绝（垫只承货物）。
			if (ttype == "box" or ttype == "iron") and _tile(bx, by) == "launcher":
				var lx: int = bx + d.x * 2
				var ly: int = by + d.y * 2
				if _in_bounds(lx, ly) and _hop_enterable(lx, ly):
					bx = lx
					by = ly
					target.x = bx
					target.y = by
					_events.append({type = "launch", at = Vector2i(bx, by), otype = ttype,
						id = int(target.id), msg = "弹射垫：货物被弹到了两格之外"})
			tele.object_move += 1
			solution_seq.append("push:" + ttype)
			_events.append({type = "push", id = int(target.id), otype = ttype,
				from = Vector2i(nx, ny), to = Vector2i(bx, by)})
			# EXT-50 双踩板：货压最终落点计一次"进入"（油道/弹射滑移末段为准）
			_count_double_at(bx, by)
			# EXT-7 挪灶：移动火把落地时点燃四邻 ice 格的融化倒计时（第二热源入口，同 TORCH_MELT_TIME）
			if ttype == "torch_m":
				_arm_melt_around(bx, by)
		_events.append({type = "move", from = Vector2i(px, py), to = Vector2i(nx, ny), dir = dir})
		player = {x = nx, y = ny}
		facing = dir
		steps += 1
		solution_seq.append("move:" + dir)
		_after_step(nx, ny)
		return true
	# 空格：水/坑不可走，关门不可进
	if tile == "water" or tile == "pit":
		return false
	# EXT-23 疑路：暗坑踩上即露馅成 pit（本步拒绝、玩家原地；之后按普通深坑语义）
	if tile == "hidden_pit":
		_set_tile(nx, ny, "pit")
		_events.append({type = "reveal", at = Vector2i(nx, ny)})
		return false
	if tile == "gate" and not gate_open():
		return false
	# EXT-36 锁门：只认钥匙——无 key 拒行（同关门手感），有 key 可进（过关在 _after_step）
	if tile == "locked_gate" and not has_key:
		return false
	# EXT-20 脆壁：碰即碎（本步直接通行；永久 floor）
	if tile == "crumble":
		_set_tile(nx, ny, "floor")
		_events.append({type = "crumble", at = Vector2i(nx, ny)})
	# EXT-34 推塌桩：只认推力——玩家行走撞上被弹回（与脆壁互为镜像：脆壁一碰就碎）
	if tile == "push_stub":
		return false
	# EXT-36 钥匙：踩上即拾取（tile 变 floor + has_key；不额外计步，本步本身是 move）
	if tile == "key_item":
		_set_tile(nx, ny, "floor")
		has_key = true
		_events.append({type = "pickup", at = Vector2i(nx, ny), msg = "捡到了黄铜钥匙"})
	# EXT-42 银钥：同式拾取（独立旗标）
	if tile == "key_silver":
		_set_tile(nx, ny, "floor")
		has_silver = true
		_events.append({type = "pickup", at = Vector2i(nx, ny), msg = "捡到了白银钥匙"})
	# EXT-42 银门：只认银钥——无钥拒行（同关门手感）；有钥可进（通道门，不触发过关）
	if tile == "locked_gate_s" and not has_silver:
		return false
	# EXT-43 潮闸：闭窗拒行（同关门手感）；开窗可进（通道，不触发过关）
	if tile == "tide_gate" and not tide_gate_open():
		return false
	# EXT-17 间歇泉：热源地形不可通行
	if tile == "vent":
		return false
	# EXT-19 寒泉：冷源地形不可通行
	if tile == "cold_vent":
		return false
	# EXT-24 相位桥：闭窗为水不可进（开窗同普通填土地面）
	if tile == "phase_bridge" and not phase_gate_open():
		return false
	# EXT-27 联动桥位：联动开关未全压住时为水不可进（压住时同普通填土地面）
	if tile == "link_slot" and not _link_pressed():
		return false
	# EXT-31 潮汐格：淹没半周期为水不可进（露出半周期同普通填土地面）
	if tile == "tide_cell" and not tide_open():
		return false
	# EXT-33 反相潮汐格：闭窗半周期为水不可进（开窗 [2,6) 同普通填土地面）
	if tile == "tide_late" and not tide_late_open():
		return false
	# EXT-13/15 相位门：闭相不可进（开相同普通门格；反相门与正相门互补开合）
	if tile == "phase_gate" and not phase_gate_open():
		return false
	if tile == "phase_gate_inv" and not phase_gate_inv_open():
		return false
	# EXT-8 单向格：入向须与箭头一致（逆行入格拒绝；出格任意方向）
	if _oneway_allow(tile) != "" and _oneway_allow(tile) != dir:
		return false
	# EXT-9 传送对格：入门即传送到对格。对格被实体（箱/铁/火把）占据 → 整步拒绝；
	# 到达对格不重复触发传送（防乒乓）；跳过 _after_step（传送落格无板/门语义）。
	if _portal_pair(tile) != "":
		var dest: Vector2i = _portal_find(_portal_pair(tile))
		if dest.x < 0 or not _solid_at(dest.x, dest.y).is_empty():
			return false
		_events.append({type = "teleport", from = Vector2i(nx, ny), to = dest})
		player = {x = dest.x, y = dest.y}
		facing = dir
		steps += 1
		solution_seq.append("move:" + dir)
		return true
	# EXT-12 滑冰格：入格后顺入向连滑——仅经 slide_ice 延续，遇实体/阻挡/特殊格即停；
	# 整段计 1 步 1 个 move 事件（事件 to = 最终落点，表现层一次滑移到位）
	if tile == "slide_ice":
		while _tile(nx, ny) == "slide_ice":
			var sx: int = nx + d.x
			var sy: int = ny + d.y
			if not _in_bounds(sx, sy) or not _slide_enterable(sx, sy):
				break
			nx = sx
			ny = sy
	# EXT-29 油道：入格后顺入向连滑——仅经 grease 延续（与冰道互不接力），遇实体/阻挡即停；
	# 整段计 1 步 1 个 move 事件（to = 最终落点）
	if tile == "grease":
		while _tile(nx, ny) == "grease":
			var gx: int = nx + d.x
			var gy: int = ny + d.y
			if not _in_bounds(gx, gy) or not _slide_enterable(gx, gy):
				break
			nx = gx
			ny = gy
	# EXT-14 弹簧垫：入门后定距二格跳——中间格无视（可越水/墙），跳点 _hop_enterable 才落；
	# 跳点不可达则停在垫上（入格本身成功）。整段计 1 步 1 个 move 事件（to=落点）。
	if tile == "spring":
		var jx: int = nx + d.x * 2
		var jy: int = ny + d.y * 2
		if _in_bounds(jx, jy) and _hop_enterable(jx, jy):
			nx = jx
			ny = jy
	_events.append({type = "move", from = Vector2i(px, py), to = Vector2i(nx, ny), dir = dir})
	player = {x = nx, y = ny}
	facing = dir
	steps += 1
	solution_seq.append("move:" + dir)
	# EXT-3：玩家踏上薄冰 → 碎裂回水（单次通行；推物/磁拉落点已拒绝 thin_ice）
	if tile == "thin_ice":
		_set_tile(nx, ny, "water")
		_events.append({type = "crack", at = Vector2i(nx, ny), msg = "薄冰碎了！"})
	# EXT-6：玩家踏上重置石 → 重载当前房（箱/板/门/薄冰全复原，玩家回 P；steps/tele 保留 = 基线 load_room 语义）
	if tile == "reset_stone":
		var ri := room_idx
		load_room(ri)
		_events.append({type = "room_reset", room_idx = ri, msg = "回声石嗡鸣——房间恢复了最初的样子"})
		return true
	_after_step(nx, ny)
	return true


# ---------------- 核心动作：工具 ----------------

func try_tool(tool: String, dir: String) -> bool:
	# EXT-27 联桥：支撑惰性结算（磁拉把铁拉离联动开关时，下一次动作前断桥落地）
	_eval_link_bridges()
	if state != "play" or not DIR_VECS.has(dir):
		return false
	if not tools.has(tool):
		return false
	var d: Vector2i = DIR_VECS[dir]
	var tx: int = int(player.x) + d.x
	var ty: int = int(player.y) + d.y
	if not _in_bounds(tx, ty):
		return false
	if tool == "ice":
		# EXT-5：F 对薄冰 → 淬成永久冰（新工具交互）；对水仍为冻结造冰（基线不变）
		if _tile(tx, ty) == "thin_ice":
			_set_tile(tx, ty, "ice")
			tele.tool_use += 1
			tele.freeze += 1
			solution_seq.append("tool:ice:" + dir)
			_events.append({type = "freeze", at = Vector2i(tx, ty), msg = "冰霜杖：薄冰淬成了坚固的冰面"})
			return true
		if _tile(tx, ty) != "water":
			return false
		_set_tile(tx, ty, "ice")
		_arm_torch_melt(tx, ty)
		tele.tool_use += 1
		tele.freeze += 1
		solution_seq.append("tool:ice:" + dir)
		_events.append({type = "freeze", at = Vector2i(tx, ty), msg = "冰霜杖：面前的水冻成了冰面"})
		return true
	if tool == "fire":
		# 差异3 兼容基线：先查面前木箱（含冰上的），烧箱优先于融冰
		var o := _solid_at(tx, ty)
		if not o.is_empty() and String(o.type) == "box":
			objects.erase(o)
			tele.tool_use += 1
			tele.burn += 1
			solution_seq.append("tool:fire:burn:" + dir)
			_events.append({type = "burn", id = int(o.id), at = Vector2i(tx, ty), msg = "火把：木箱烧成了灰"})
			return true
		# EXT-11：裂纹墙可烧毁成 floor（G×地形新交互；墙内无实体/冰，与上两分支互斥）
		if _tile(tx, ty) == "cracked_wall":
			_set_tile(tx, ty, "floor")
			tele.tool_use += 1
			tele.burn += 1
			solution_seq.append("tool:fire:burn_wall:" + dir)
			_events.append({type = "burn_wall", at = Vector2i(tx, ty), msg = "火把：裂纹墙轰然塌开，路通了"})
			return true
		# EXT-46：藤蔓可烧毁成 floor（G×ivy——人货分流阀可改写：玩家本可攀越，货物
		# 被藤挡死，烧穿一格即通；不可逆，其余藤格照旧；序列串不进分类器——差异5 冻结）
		if _tile(tx, ty) == "ivy":
			_set_tile(tx, ty, "floor")
			tele.tool_use += 1
			tele.burn += 1
			solution_seq.append("tool:fire:burn_ivy:" + dir)
			_events.append({type = "burn_wall", at = Vector2i(tx, ty), msg = "火把：藤蔓燃尽，地上只剩一段焦痕"})
			return true
		if _tile(tx, ty) == "ice":
			# 先结算融化（可能产生 melt 事件/移动玩家），再计工具遥测与序列——顺序与旧 391-394 行一致
			_melt_ice_tile(tx, ty)
			tele.tool_use += 1
			tele.melt += 1
			solution_seq.append("tool:fire:melt:" + dir)
			return true
		return false
	if tool == "magnet":
		# 沿正交方向找最近铁块/冰晶（EXT-47 起磁认晶——"磁不认"翻转）；只有格子 wall/ivy
		# 截断视线（箱/铁/火把/装饰都不挡；EXT-37 藤蔓墙对货物与磁拉等同墙——只有玩家能攀越）
		var cx: int = tx
		var cy: int = ty
		while _in_bounds(cx, cy):
			if _tile(cx, cy) == "wall" or _tile(cx, cy) == "ivy":
				break
			var o2 := _solid_at(cx, cy)
			if not o2.is_empty() and (String(o2.type) == "iron" or String(o2.type) == "crystal"):
				var fx: int = cx - d.x
				var fy: int = cy - d.y
				if fx == int(player.x) and fy == int(player.y):
					return false
				var ft := _tile(fx, fy)
				# 差异2 兼容基线：磁拉落点仅 floor/ice 且无实体、非玩家格
				if (ft != "floor" and ft != "ice" and ft != "reset_stone") or not _solid_at(fx, fy).is_empty():
					return false
				var from_v := Vector2i(cx, cy)
				o2.x = fx
				o2.y = fy
				tele.tool_use += 1
				tele.object_move += 1
				solution_seq.append("tool:magnet:" + dir)
				_events.append({type = "magnet", id = int(o2.id), otype = String(o2.type),
					from = from_v, to = Vector2i(fx, fy), msg = "磁石：最近的可磁物被拉近了一格"})
				return true
			cx += d.x
			cy += d.y
		return false
	return false


# ---------------- 定时融化（明确游戏时间；表现层暂停时不调用本方法即可暂停） ----------------

## 旧 _process 融冰段等价：从队尾向队首逐项倒计时，同帧到期按队尾先结算
func advance_time(dt: float) -> void:
	# EXT-13：相位门时钟恒累计（无相位门的房间累计无副作用——Z 格不存在即无判定）
	var phase_was_open := phase_gate_open()
	var tide_was_open := tide_open()
	var tide_late_was_open := tide_late_open()
	phase_clock += dt
	# EXT-24 相位桥：开窗→闭窗瞬间结算桥面（玩家弹回/重物移除；地形本身不变）
	if not phase_bridges.is_empty() and phase_was_open and not phase_gate_open():
		_close_phase_bridges()
	# EXT-31 潮汐：露出→淹没瞬间结算潮格（玩家弹回/重物移除；地形本身不变）
	if not tide_cells.is_empty() and tide_was_open and not tide_open():
		_close_tide_cells(tide_cells)
	# EXT-33 反相潮汐：同构结算（闭窗 [6,8)+[0,2)）
	if not tide_late_cells.is_empty() and tide_late_was_open and not tide_late_open():
		_close_tide_cells(tide_late_cells)
	# EXT-17：间歇泉相位累计，过喷发周期点则全图喷发一次（融化各泉口四邻冰）
	vent_clock += dt
	# EXT-19：寒泉半周期喷发（与热泉错相——同一格被 Q/V 夹住即呼吸桥）
	if vent_clock >= VENT_PERIOD * 0.5 and not cold_fired:
		cold_fired = true
		_freeze_cold_vents()
	while vent_clock >= VENT_PERIOD:
		vent_clock -= VENT_PERIOD
		cold_fired = false
		_fire_vents()
	# EXT-35 暖轨车：整步进周期走一格（撞阻反转、该拍原地等待）
	cart_clock += dt
	while cart_clock >= CART_PERIOD:
		cart_clock -= CART_PERIOD
		_cart_step()
	# EXT-40 输送带：整拍步进，带上物/人沿带向一格（落点不合法原地等待）
	belt_clock += dt
	while belt_clock >= BELT_PERIOD:
		belt_clock -= BELT_PERIOD
		_belt_step()
	var k := melt_queue.size() - 1
	while k >= 0:
		var m: Dictionary = melt_queue[k]
		m.left = float(m.left) - dt
		if float(m.left) <= 0.0:
			_melt_ice_tile(int(m.x), int(m.y))
			melt_queue.remove_at(k)
		k -= 1


func _arm_torch_melt(x: int, y: int) -> void:
	var offsets := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for off_v in offsets:
		var off: Vector2i = off_v
		var ox: int = x + off.x
		var oy: int = y + off.y
		if _in_bounds(ox, oy):
			var o := _solid_at(ox, oy)
			if not o.is_empty() and (String(o.type) == "torch" or String(o.type) == "torch_m"):
				melt_queue.append({x = x, y = y, left = TORCH_MELT_TIME})
				return


## EXT-35 暖轨车：自主巡轨热源——沿出生行东西往返，撞阻反转（该拍原地等待）。
## 进格结算：轨上木箱按火语义焚烧（burn 事件 + tele.burn，火把同款）；轨下冰面熔化成水
## （melt 事件刷地；tele.melt 口径不变——仍只计工具融冰）。车不进 gate、不伤人、铁不燃。
func _cart_step() -> void:
	var cart := _cart()
	if cart.is_empty():
		return
	var cy := int(cart.y)
	var nx: int = int(cart.x) + cart_dir
	if not _in_bounds(nx, cy) or not _cart_lane_enterable(nx, cy) \
			or (int(player.x) == nx and int(player.y) == cy):
		# 撞墙/关门/玩家占格：反转等待（车不伤人）
		cart_dir = -cart_dir
		return
	var occupant := _solid_at(nx, cy)
	if not occupant.is_empty():
		if String(occupant.type) == "box":
			# 轨上木箱按火语义焚烧，车继续进格
			var box_id := int(occupant.id)
			objects.erase(occupant)
			tele.burn += 1
			_events.append({type = "burn", id = box_id, at = Vector2i(nx, cy),
				msg = "暖轨车：轨上的木箱烤成了灰"})
		else:
			# 铁墩/火把挡轨：铁不燃（差异1基线火只烧木箱），反转等待
			cart_dir = -cart_dir
			return
	var from := Vector2i(int(cart.x), cy)
	cart.x = nx
	# EXT-56 车越堑：进格落垫沿行进向弹 2 格（一拍跨 3 格、中间格无视）——落点界外/
	# 非轨面/玩家/铁墩等固形物 → 留垫（下一拍从垫再判，与 EXT-26 箱弹射留垫同款）；
	# 弹落点木箱按轨上火语义焚烧（车落在那）
	if _tile(nx, cy) == "launcher":
		var hx56: int = nx + cart_dir * 2
		if _in_bounds(hx56, cy) and _cart_lane_enterable(hx56, cy) and int(player.x) != hx56:
			var hop_occ56 := _solid_at(hx56, cy)
			if hop_occ56.is_empty():
				nx = hx56
				cart.x = nx
			elif String(hop_occ56.type) == "box":
				objects.erase(hop_occ56)
				tele.burn += 1
				_events.append({type = "burn", id = int(hop_occ56.id), at = Vector2i(hx56, cy),
					msg = "暖轨车：弹落点的木箱烤成了灰"})
				nx = hx56
				cart.x = nx
	# EXT-55 车碾板：进格落点计双踩板踩占（进入沿；巡轨往返反复碾=反复计数至 latch）
	_count_double_at(nx, cy)
	if _tile(nx, cy) == "ice":
		_set_tile(nx, cy, "water")
		_events.append({type = "melt", at = Vector2i(nx, cy), occupant = "", result = "water",
			msg = "暖轨车碾过冰面，冰化成了水"})
	_events.append({type = "cart_move", id = int(cart.id), from = from, to = Vector2i(nx, cy)})


func _cart() -> Dictionary:
	for o in objects:
		if String(o.type) == "cart":
			return o
	return {}


## EXT-35 轨面白名单：车只碾 floor/ice/water/bridge/fill（gate 永不入——终局格不被车占）；
## EXT-48 起开窗潮格可碾（车候潮：闭窗在滩前折返、开窗驶过——落潮时车在潮格上随
## 既有淹没结算沉没）
func _cart_lane_enterable(x: int, y: int) -> bool:
	var t := _tile(x, y)
	# EXT-56 车越堑：弹射垫=可入轨面（车进垫即弹——此前垫不在白名单，轨被垫截断）
	# EXT-59 候闸：潮闸=车第四候潮通道（闸开窗车过、闭窗车原地候窗——人/推箱/带运
	# 之外第四种闸通道）
	return t == "floor" or t == "ice" or t == "water" or t == "bridge" or t == "fill" \
		or t == "launcher" \
		or (t == "tide_cell" and tide_open()) or (t == "tide_late" and tide_late_open()) \
		or (t == "tide_gate" and tide_gate_open())


## EXT-40 带上落点判定：白名单地形、无固形物；物不可落到玩家格（人先让位由下一拍补）
func _belt_landing_ok(x: int, y: int, for_player: bool) -> bool:
	if not _in_bounds(x, y):
		return false
	var t := _tile(x, y)
	if t != "floor" and t != "ice" and t != "reset_stone" and t != "spring" \
			and t != "grease" and t != "slide_ice" and t != "launcher" \
			and t != "belt_e" and t != "belt_w" and t != "belt_s" and t != "belt_n" \
			and not (t == "tide_gate" and tide_gate_open()) \
			and not (t == "tide_cell" and tide_open()) \
			and not (t == "tide_late" and tide_late_open()) \
			and not (t == "phase_bridge" and phase_gate_open()):
		return false
	if not _solid_at(x, y).is_empty():
		return false
	if not for_player and int(player.x) == x and int(player.y) == y:
		return false
	return true


func _is_belt(x: int, y: int) -> bool:
	var t := _tile(x, y)
	return t == "belt_e" or t == "belt_w" or t == "belt_s" or t == "belt_n"


## EXT-41 带向泛化：四向 Vector2i（e/w/s/n），非带格返回 ZERO
func _belt_dir(x: int, y: int) -> Vector2i:
	match _tile(x, y):
		"belt_e":
			return Vector2i(1, 0)
		"belt_w":
			return Vector2i(-1, 0)
		"belt_s":
			return Vector2i(0, 1)
		"belt_n":
			return Vector2i(0, -1)
	return Vector2i.ZERO


## EXT-40 门沿判定（开关导通由关到开计一次 switch_on + gate_open 事件）；带搬运后与
## _after_step 共用同一份口径
func _update_gate_edge() -> void:
	var g_now := gate_open()
	if g_now and not gate_was_open:
		tele.switch_on += 1
		_events.append({type = "gate_open"})
	gate_was_open = g_now


## EXT-40 输送带：每拍先物后人——带上 box/iron 沿带向移一格，随后带上的玩家同向移一格；
## 落点不合法原地等待（带不沉货 v1：水/坑/板/门/固形物一律不动）。有搬运则刷新门沿。
## 快照式：拍前定格"带货者"名单，一拍至多一格——防行序串联把同一物连搬多格。
func _belt_step() -> void:
	if belts.is_empty():
		return
	var moved := false
	var riders: Array = []
	for b_v in belts:
		var b: Vector2i = b_v
		var occ := _solid_at(int(b.x), int(b.y))
		if not occ.is_empty() and (String(occ.type) == "box" or String(occ.type) == "iron" \
				or String(occ.type) == "crystal"):
			riders.append({cell = b, occ = occ, dir = _belt_dir(int(b.x), int(b.y))})
	for r_v in riders:
		var r: Dictionary = r_v
		var occ: Dictionary = r.occ
		var cell: Vector2i = r.cell
		var dir: Vector2i = r.dir
		var lx: int = int(cell.x) + int(dir.x)
		var ly: int = int(cell.y) + int(dir.y)
		# EXT-44 晶运：晶随带行驶——带尾出带（落点非带）即碎成水（落点可 F 冻桥）；
		# 落点非法（墙/实体/玩家/冰面等）原地等待（与箱同款排队）
		var occ_is_crystal := String(occ.type) == "crystal"
		var can_move := false
		var shatter_ramp := false
		if occ_is_crystal:
			var lt := _tile(lx, ly)
			var lt_belt := lt == "belt_e" or lt == "belt_w" or lt == "belt_s" or lt == "belt_n"
			if lt_belt:
				can_move = _belt_landing_ok(lx, ly, false)
			elif (lt == "tide_cell" and tide_open()) or (lt == "tide_late" and tide_late_open()) \
					or (lt == "phase_bridge" and phase_gate_open()):
				# EXT-57 晶潮渡：带运晶驶入开窗潮格落驻（不出带碎；闭窗原地候窗与箱同款
				# 排队）——落驻后闭窗走 EXT-51 潮磨结算：晶被碾成永久水池（带=摆渡、潮=磨坊）
				# EXT-58 桥渡：开窗相位桥同款落驻（闭窗桥面=水不可落候窗；滞留桥面跨闭窗
				# 走 EXT-24 phase_drop 既有结算——桥是障碍型时机关，晶过桥须一气呵成）
				can_move = _belt_landing_ok(lx, ly, false)
			elif (lt == "floor" or lt == "water" or lt == "pit") \
					and _solid_at(lx, ly).is_empty() \
					and not (int(player.x) == lx and int(player.y) == ly):
				shatter_ramp = true
		else:
			can_move = _belt_landing_ok(lx, ly, false)
		if can_move:
			var from_v := Vector2i(int(cell.x), int(cell.y))
			occ.x = lx
			occ.y = ly
			moved = true
			_events.append({type = "belt_move", id = int(occ.id), otype = String(occ.type),
				from = from_v, to = Vector2i(lx, ly)})
		elif shatter_ramp:
			var ramp_id := int(occ.id)
			objects.erase(occ)
			_set_tile(lx, ly, "water")
			moved = true
			_events.append({type = "shatter", id = ramp_id, at = Vector2i(lx, ly),
				msg = "冰晶随带到站，碎成了一汪清水"})
	# EXT-58 桥渡：开窗相位桥上的货物沿来带方向同拍续行（桥面=带线的延续——落驻即走
	# 不滞留；闭窗跨桥面走 _close_phase_bridges phase_drop 既有结算）
	if phase_gate_open():
		for b3_v in phase_bridges:
			var b3: Vector2i = b3_v
			var occ3 := _solid_at(int(b3.x), int(b3.y))
			if occ3.is_empty() or (String(occ3.type) != "box" and String(occ3.type) != "iron" \
					and String(occ3.type) != "crystal"):
				continue
			var dir3 := _bridge_dir(b3)
			if dir3 == Vector2i.ZERO:
				continue
			var lx3: int = int(b3.x) + int(dir3.x)
			var ly3: int = int(b3.y) + int(dir3.y)
			if _belt_landing_ok(lx3, ly3, false):
				occ3.x = lx3
				occ3.y = ly3
				moved = true
				_events.append({type = "belt_move", id = int(occ3.id), otype = String(occ3.type),
					from = Vector2i(int(b3.x), int(b3.y)), to = Vector2i(lx3, ly3)})
	# EXT-45 潮渡接引：带后相邻的开窗潮格上的箱/铁由该带"接引"过滩——
	# 货落潮格不再是死点（闭窗/落点不合法则原地候潮；潮没危险照常）
	for b_v in belts:
		var b2: Vector2i = b_v
		var dir_b := _belt_dir(int(b2.x), int(b2.y))
		var behind := Vector2i(int(b2.x) - int(dir_b.x), int(b2.y) - int(dir_b.y))
		var bt := _tile(int(behind.x), int(behind.y))
		var tide_ok := (bt == "tide_cell" and tide_open()) \
			or (bt == "tide_late" and tide_late_open())
		if not tide_ok:
			continue
		var occ2 := _solid_at(int(behind.x), int(behind.y))
		if occ2.is_empty() or (String(occ2.type) != "box" and String(occ2.type) != "iron"):
			continue
		if _belt_landing_ok(int(b2.x), int(b2.y), false):
			var from_v2 := Vector2i(int(behind.x), int(behind.y))
			occ2.x = int(b2.x)
			occ2.y = int(b2.y)
			moved = true
			_events.append({type = "belt_move", id = int(occ2.id), otype = String(occ2.type),
				from = from_v2, to = Vector2i(int(b2.x), int(b2.y))})
	if _is_belt(int(player.x), int(player.y)):
		var dir_p: Vector2i = _belt_dir(int(player.x), int(player.y))
		var px2: int = int(player.x) + int(dir_p.x)
		var py2: int = int(player.y) + int(dir_p.y)
		if _belt_landing_ok(px2, py2, true):
			_events.append({type = "belt_move", otype = "player",
				from = Vector2i(int(player.x), int(player.y)), to = Vector2i(px2, py2)})
			player = {x = px2, y = py2}
			moved = true
	# EXT-58 桥渡：开窗相位桥上的玩家沿来带方向同拍续行（顺序 if——带上落桥与桥面
	# 续行同拍完成，玩家不滞留桥面跨闭窗；闭窗滞留走弹回兜底）
	if _tile(int(player.x), int(player.y)) == "phase_bridge" and phase_gate_open():
		var dir_pb: Vector2i = _bridge_dir(Vector2i(int(player.x), int(player.y)))
		if dir_pb != Vector2i.ZERO:
			var px3: int = int(player.x) + int(dir_pb.x)
			var py3: int = int(player.y) + int(dir_pb.y)
			if _belt_landing_ok(px3, py3, true):
				_events.append({type = "belt_move", otype = "player",
					from = Vector2i(int(player.x), int(player.y)), to = Vector2i(px3, py3)})
				player = {x = px3, y = py3}
				moved = true
	if moved:
		_eval_link_bridges()
		_update_gate_edge()


## EXT-58 桥渡：相位桥格的续行方向——找四邻中指向本桥的带（带向 = 离桥向），
## 桥面货/人沿该方向同拍续走；无来带（孤桥）返回 ZERO 不动。
func _bridge_dir(b: Vector2i) -> Vector2i:
	for off_v in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var off: Vector2i = off_v
		var nb := b + off
		if _is_belt(int(nb.x), int(nb.y)):
			var bd := _belt_dir(int(nb.x), int(nb.y))
			if int(bd.x) == -int(off.x) and int(bd.y) == -int(off.y):
				return bd
	return Vector2i.ZERO


## EXT-7 挪灶：torch_m 落点 (x,y) 四邻的 ice 格入融化队列（可搬运的热源；到期 _melt_ice_tile
## 自检 tile=="ice"，重复入队/冰已变桥均为无害空转）。与冻冰路径 _arm_torch_melt 同队列同秒数。
func _arm_melt_around(x: int, y: int) -> void:
	var offsets := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for off_v in offsets:
		var off: Vector2i = off_v
		var ox: int = x + off.x
		var oy: int = y + off.y
		if _in_bounds(ox, oy) and _tile(ox, oy) == "ice":
			melt_queue.append({x = ox, y = oy, left = TORCH_MELT_TIME})


## 融化统一结算三分支：冰上箱→erase+bridge；冰上铁→erase+water；玩家在冰上→退回最近可站立格+water；空冰→water。
## 遥测 melt 不在这里计（只计工具路径）；环境路径不写 solution_seq——差异5/口径与旧版一致。
## EXT-24 相位桥闭窗结算：桥上重物失去支撑移除（融化三分支先例；地形不变仍是相位桥）、
## 玩家退回最近可站立格（找不到落点则留在原格——闭窗桥面可步行出格，无死锁）。
## 遥测不计数、不写 solution_seq（环境路径口径与融化一致）。
func _close_phase_bridges() -> void:
	for pb_v in phase_bridges:
		var pb: Vector2i = pb_v
		var occupant := _solid_at(int(pb.x), int(pb.y))
		if not occupant.is_empty():
			var ot := String(occupant.type)
			objects.erase(occupant)
			_events.append({type = "phase_drop", at = Vector2i(int(pb.x), int(pb.y)), occupant = ot,
				id = int(occupant.id), msg = "相位桥合拢：" + ot + "失去了支撑"})
			continue
		if int(player.x) == int(pb.x) and int(player.y) == int(pb.y):
			var spot := _nearest_standing_spot(int(pb.x), int(pb.y))
			var ev := {type = "phase_drop", at = Vector2i(int(pb.x), int(pb.y)), occupant = "player",
				msg = "相位桥合拢了，你退回了旁边的地面"}
			if not spot.is_empty():
				ev.player_from = Vector2i(int(player.x), int(player.y))
				player = {x = int(spot.x), y = int(spot.y)}
				ev.player_to = Vector2i(int(spot.x), int(spot.y))
			_events.append(ev)


## EXT-27 联桥惰性结算：联动开关松开后，桥上的重物失去支撑移除、玩家退回最近可站立格
## （融化三分支先例；地形不变仍是 link_slot，重压即复通）。支撑在每次动作开始前重估。
## 遥测不计数、不写 solution_seq（环境路径口径与融化一致）。
func _eval_link_bridges() -> void:
	if link_slots.is_empty() or _link_pressed():
		return
	for ls_v in link_slots:
		var ls: Vector2i = ls_v
		var occupant := _solid_at(int(ls.x), int(ls.y))
		if not occupant.is_empty():
			var ot := String(occupant.type)
			objects.erase(occupant)
			_events.append({type = "link_break", at = Vector2i(int(ls.x), int(ls.y)), occupant = ot,
				id = int(occupant.id), msg = "联动桥断了：" + ot + "失去了支撑"})
			continue
		if int(player.x) == int(ls.x) and int(player.y) == int(ls.y):
			var spot := _nearest_standing_spot(int(ls.x), int(ls.y))
			var ev := {type = "link_break", at = Vector2i(int(ls.x), int(ls.y)), occupant = "player",
				msg = "联动桥断了，你退回了旁边的地面"}
			if not spot.is_empty():
				ev.player_from = Vector2i(int(player.x), int(player.y))
				player = {x = int(spot.x), y = int(spot.y)}
				ev.player_to = Vector2i(int(spot.x), int(spot.y))
			_events.append(ev)


func _melt_ice_tile(x: int, y: int) -> bool:
	if _tile(x, y) != "ice":
		return false
	var occupant := _solid_at(x, y)
	if not occupant.is_empty():
		var ot := String(occupant.type)
		if ot == "box":
			var box_id := int(occupant.id)
			objects.erase(occupant)
			_set_tile(x, y, "bridge")
			_events.append({type = "melt", at = Vector2i(x, y), occupant = "box", id = box_id, result = "bridge",
				msg = "冰面融化：木箱失去支撑沉了下去，成了一座桥"})
			return true
		if ot == "iron":
			var iron_id := int(occupant.id)
			objects.erase(occupant)
			_set_tile(x, y, "water")
			_events.append({type = "melt", at = Vector2i(x, y), occupant = "iron", id = iron_id, result = "water",
				msg = "冰面融化：铁块失去支撑沉入了水底"})
			return true
	if int(player.x) == x and int(player.y) == y:
		var spot := _nearest_standing_spot(x, y)
		var ev := {type = "melt", at = Vector2i(x, y), occupant = "player", result = "water",
			msg = "脚下的冰面融化了，你退回了旁边的地面"}
		if not spot.is_empty():
			ev.player_from = Vector2i(int(player.x), int(player.y))
			player = {x = int(spot.x), y = int(spot.y)}
			ev.player_to = Vector2i(int(spot.x), int(spot.y))
		# 兼容基线（审计 §3-2）：找不到落点时玩家留在原格、该格照样变水（玩家可站在水上）
		_set_tile(x, y, "water")
		_events.append(ev)
		return true
	_set_tile(x, y, "water")
	_events.append({type = "melt", at = Vector2i(x, y), occupant = "", result = "water"})
	return true


## 退回次序（兼容基线，非 BFS）：半径 1..N 环序，环内先四正交射线再四对角位置；可能跨过阻隔
func _nearest_standing_spot(x: int, y: int) -> Dictionary:
	var ortho := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	var diag := [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]
	for r in range(1, ROOM_W + ROOM_H):
		for off_v in ortho:
			var off: Vector2i = off_v
			var nx: int = x + off.x * r
			var ny: int = y + off.y * r
			if _in_bounds(nx, ny) and _standable(nx, ny):
				return {x = nx, y = ny}
		for off_v2 in diag:
			var off2: Vector2i = off_v2
			var nx2: int = x + off2.x * r
			var ny2: int = y + off2.y * r
			if _in_bounds(nx2, ny2) and _standable(nx2, ny2):
				return {x = nx2, y = ny2}
	return {}


func _standable(x: int, y: int) -> bool:
	var t := _tile(x, y)
	if t == "wall" or t == "water" or t == "pit" or t == "thin_ice":
		# thin_ice 承不住站立（walk 落点即时碎裂），退回落点同样排除
		return false
	if t == "gate" and not gate_open():
		return false
	if t == "locked_gate" and not has_key:
		# EXT-36 锁门：无 key 不可站（退回落点排除）；有 key 同普通门格可进
		return false
	if t == "locked_gate_s" and not has_silver:
		# EXT-42 银门：无银钥不可站（退回落点排除）
		return false
	if t == "tide_gate" and not tide_gate_open():
		# EXT-43 潮闸：闭窗不可站（退回落点排除）；开窗同普通通道格
		return false
	if t == "phase_gate" and not phase_gate_open():
		return false
	if t == "phase_gate_inv" and not phase_gate_inv_open():
		return false
	if t == "vent" or t == "cold_vent":
		return false
	return _solid_at(x, y).is_empty()


# ---------------- 过房与归类 ----------------

## EXT-50 双踩板：该格有未锁定双踩板则计一次"进入"（人踩/货压/物传同口径）；
## 满 2 次永久锁定（latched）
func _count_double_at(x: int, y: int) -> void:
	for o in objects:
		var od: Dictionary = o
		if String(od.type) == "switch_double" and int(od.x) == x and int(od.y) == y \
				and not bool(od.get("latched", false)):
			od.count = int(od.get("count", 0)) + 1
			if int(od.count) >= 2:
				od.latched = true
				_events.append({type = "latch", at = Vector2i(x, y),
					msg = "双踩板：第二次踩占——机关咬合，永久导通了"})
			break


func _after_step(nx: int, ny: int) -> void:
	# EXT-18：自锁踏板——玩家踩上（落点=踏板格）即永久锁定
	for o in objects:
		var lod: Dictionary = o
		var is_latch_target: bool = String(lod.type) == "switch_latch" and int(lod.x) == nx and int(lod.y) == ny
		if is_latch_target and not bool(lod.get("latched", false)):
			lod.latched = true
			_events.append({type = "latch", at = Vector2i(nx, ny)})
	# EXT-50：双踩板——玩家每次"进入"计一次（持续占位不重复计），满 2 次永久锁定
	_count_double_at(nx, ny)
	_update_gate_edge()
	# EXT-39 换相井：踩上即相位 +4 秒——潮汐 u/j、相位门/桥即时翻转；
	# 翻转前采样开相，翻转后对"开→闭"组调用既有惰性结算（同 advance_time 的沿）
	if _tile(nx, ny) == "tide_well":
		var pb_was := phase_gate_open()
		var u_was := tide_open()
		var j_was := tide_late_open()
		phase_clock += PHASE_PERIOD
		if not phase_bridges.is_empty() and pb_was and not phase_gate_open():
			_close_phase_bridges()
		if not tide_cells.is_empty() and u_was and not tide_open():
			_close_tide_cells(tide_cells)
		if not tide_late_cells.is_empty() and j_was and not tide_late_open():
			_close_tide_cells(tide_late_cells)
		_events.append({type = "phase_shift", at = Vector2i(nx, ny),
			msg = "换相井嗡鸣——潮汐与门相翻转了"})
	# EXT-36 锁门：有钥进门即过关（与压力板门解耦——无 gate_open 门槛）
	if (_tile(nx, ny) == "gate" and gate_open()) or _tile(nx, ny) == "locked_gate":
		_classify_family()
		if room_idx == 4:
			# room5_complete 不变量：原第五房（索引 [4]）通关置 1，与 EXT 扩展房无关
			tele.room5_complete = 1
		if room_idx >= _total_rooms() - 1:
			state = "final"
			_events.append({type = "final", steps = steps, family_by_room = family_by_room.duplicate()})
		else:
			rooms_cleared += 1
			_events.append({type = "room_clear", room_idx = room_idx, family = family,
				name = String(ROOMS[room_idx].name) if room_idx < ROOMS.size() else String(ROOMS_EXT[room_idx - ROOMS.size()].name)})
			load_room(room_idx + 1)


## 差异5 兼容基线：精确串比较。"tool:fire:melt:方向"（带方向）永不命中 has_melt；
## 环境融化不写 solution_seq。优先级：融冰 > 磁拉 > 箱桥 > 冻冰 > 纯走位。
func _classify_family() -> void:
	var has_melt := false
	var has_magnet := false
	var has_bridge := false
	var has_freeze := false
	for a in solution_seq:
		var s := str(a)
		if s == "tool:fire:melt":
			has_melt = true
		elif s.begins_with("tool:magnet"):
			has_magnet = true
		elif s == "push:box:water" or s == "push:box:pit":
			has_bridge = true
		elif s.begins_with("tool:ice"):
			has_freeze = true
	if has_melt:
		family = "melt_route"
	elif has_magnet:
		family = "magnet_iron"
	elif has_bridge:
		family = "box_bridge"
	elif has_freeze:
		family = "freeze_route"
	else:
		family = "plain"
	if not family_by_room.has(room_idx):
		family_by_room[room_idx] = family
