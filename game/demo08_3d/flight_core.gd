class_name Demo08FlightCore
extends RefCounted
## DEMO8 3D 迁移 · 阶段 A 规则核心（回归桥梁，旧 px 单位）
## 从 demo08_paperplane.gd 原样提取：折线参数汇总、纵向/高度积分、高低门、终点/落地/超时判定、经济与商店。
## 数值公式与旧版逐行等价（相同折线/角度/力度/delta 下轨迹与币数一致，见 tests/test_demo08_3d.gd）。
## 不含任何视觉、输入、节点；表现层负责 60px=1m 换算与 3D 呈现。
## 新增（非经济变更）：gate_coins 单独累计本掷门奖，供结算显示拆分（旧版 coins_earned 会被结算覆盖、漏显门奖）。

const PX_PER_M := 60.0
const GRAV := 380.0             # px/s^2
const LIFT_K := 0.00095         # 升力加速度 = LIFT_K * eff_lift * speed^2，封顶 0.95g
const DRAG_K := 0.00009         # 阻力加速度 = DRAG_K * (BASE_DRAG + drag_f) * speed^2
const BASE_DRAG := 0.35
const LAUNCH_V := 1150.0        # 满力初速 px/s
const PITCH_FOLLOW := 3.0       # 机头追随速度方向的速率（1/s）
const PROP_THRUST := 120.0      # 螺旋桨恒推力 px/s^2（沿机头方向）
const TAIL_THRUST := 90.0       # 顺风恒定推力 px/s^2（沿 +x）
const DIVE_ACCEL := 320.0       # C88 俯冲下压 px/s^2（S/↓ 按住时叠加在重力上）
const HEAD_DRAG_MULT := 1.25    # 逆风阻力倍率
const MAX_FLIGHT_TIME := 14.0
const LIFT_PER_FOLD := 0.45
const TRIM_PER_FOLD := 0.35
const DRAG_PER_FOLD := 0.18
const CHARGE_TIME := 1.2
const GROUND_Y := 460.0
const START_X := 60.0
const SAMPLE_STEP := 0.2
const FOLD_TOLERANCE := 10.0    # 折线端点落在放宽 10px 的纸面内才接受

## ---- 阶段 B1 新增规则（规则变化 B1，单独记录，2D 对照与无输入行为不受影响）----
## A/D 有限侧向转向：升力仍按旧纵向/高度速度计算（不耦合）；
## 侧向为独立运动学：按住横向加速、无输入线性阻尼衰减、速度上限公开；
## 高低门获得横向有效宽度（出界穿越不计门），赛道横向边界 ±20m 贴边清速。
const LAT_ACCEL := 240.0        # A/D 按住横向加速度 px/s^2
const LAT_VMAX := 320.0         # 横向速度上限 px/s
const LAT_DAMP := 160.0         # 无输入横向阻尼 px/s^2
const LAT_LIMIT_PX := 1200.0    # 横向边界半宽 20m
const GATE_HALF_PX := 300.0     # 门横向有效半宽 5m
const LAT_WIND := 60.0          # 阶段 C2 新机制：侧风恒定横向加速度 px/s²（wind="side" 时生效，方向由 wind_side）

const LEVELS := [
	{name = "第 1 关 · 后山操场", short = "后山操场", ratio = 1.4, folds = 3, target_m = 30.0, wind = "none", reward = 0,
		tip = "纸最宽好折大翼，终点 30 米，无风。折线画在纸的右侧偏上，30 度满力扔"},
	{name = "第 2 关 · 教学楼顶", short = "教学楼顶", ratio = 1.0, folds = 4, target_m = 45.0, wind = "head", reward = 6,
		gate_x = 34.0, gate_h = 12.0, gate_bonus = 3, low_gate_x = 40.0, low_gate_top = 10.0,
		tip = "逆风阻力 1.25 倍，终点 45 米；34 米高空门（12m 以上）+3、40 米低空门（10m 以下）+3——抬头吃高门、俯冲吃低门、求稳直通"},
	{name = "第 3 关 · 河堤风口", short = "河堤风口", ratio = 0.8, folds = 5, target_m = 65.0, wind = "tail", reward = 10,
		tip = "纸最窄可折 5 次，顺风给恒定推力，终点 65 米，顺风送你一程"},
	{name = "第 4 关 · 双门峡谷", short = "双门峡谷", ratio = 0.7, folds = 5, target_m = 55.0, wind = "head", reward = 12,
		gate_x = 34.0, gate_h = 12.0, gate_bonus = 3, gate_side = -480.0, low_gate_x = 40.0, low_gate_top = 10.0, low_gate_side = 480.0,
		tip = "逆风峡谷 55 米：高门在左（-8m 横位）、低门在右（+8m 横位），A/D 横移二选一——抬头左飘吃高门、俯冲右切吃低门、求稳直通"},
	{name = "第 5 关 · 远程投递", short = "远程投递", ratio = 0.6, folds = 6, target_m = 85.0, wind = "tail", reward = 14,
		gate_x = 50.0, gate_h = 14.0, gate_bonus = 4,
		tip = "顺风最长关 85 米，可折 6 次；50 米高空门（14m 以上）+4，折飘一点把门也一起收了"},
	{name = "第 6 关 · 侧风走廊", short = "侧风走廊", ratio = 0.9, folds = 5, target_m = 60.0, wind = "side", wind_side = -1.0, reward = 12,
		gate_x = 35.0, gate_h = 11.0, gate_bonus = 3,
		tip = "侧风向左推（60px/s²），按住 D 顶住风向保住中线；35 米高空门（11m 以上）+3，60 米过关。更多机制关卡（用户指令扩展，五关原始配置未动）"},
	{name = "第 7 关 · 回风峡谷", short = "回风峡谷", ratio = 0.85, folds = 6, target_m = 70.0, wind = "side", wind_side = 1.0, reward = 14,
		gate_x = 30.0, gate_h = 12.0, gate_bonus = 3, gate_side = -360.0,
		tip = "侧风向右推，高门却在左边（30 米、-6m 横位、12m 以上）+3：先顶风左拐吃门，再让风送你回中线滑完 70 米。更多机制关卡（用户指令扩展）"},
	{name = "第 8 关 · 风切变峡谷", short = "风切变峡谷", ratio = 0.8, folds = 6, target_m = 65.0, wind = "side", wind_side = -1.0, shear_x = 40.0, wind_side2 = 1.0, reward = 14,
		gate_x = 50.0, gate_h = 12.0, gate_bonus = 3, gate_side = -180.0,
		tip = "风切变：40 米前侧风向左带、40 米后反向向右送——被带去左边不用慌，切变后风把你送回 -3m 高空门（48 米、12m 以上）+3，65 米过关。更多机制关卡（用户指令扩展）"},
	{name = "第 9 关 · 斜风峡谷", short = "斜风峡谷", ratio = 0.85, folds = 6, target_m = 50.0, wind = "head", side_wind = -60.0, reward = 12,
		gate_x = 40.0, gate_h = 11.0, gate_bonus = 3, gate_side = 240.0,
		tip = "斜风：逆风阻力 1.25 倍，侧风还向左推（60px/s²）——顶住左漂向右切，40 米高空门（+4m 横位、11m 以上）+3，50 米过关。更多机制关卡（用户指令扩展）"},
	{name = "第 10 关 · S 形走廊", short = "S 形走廊", ratio = 0.8, folds = 6, target_m = 75.0, wind = "side", wind_side = -1.0, shear_x = 30.0, wind_side2 = 1.0, shear_x2 = 50.0, wind_side3 = -1.0, reward = 14,
		gate_x = 42.0, gate_h = 12.0, gate_bonus = 3, gate_side = 300.0,
		tip = "双段切变 S 形：30 米前左风、30-50 米右风（趁势在 +5m 横位吃 42 米高空门 +3）、50 米后左风送你收尾 75 米。更多机制关卡（用户指令扩展）"},
	{name = "第 11 关 · 摆动之门", short = "摆动之门", ratio = 0.9, folds = 6, target_m = 55.0, wind = "none", reward = 12,
		gate_x = 45.0, gate_h = 12.0, gate_bonus = 3, gate_swing = 420.0, gate_period = 3.0,
		tip = "门横位随时间摆动（±7m，3 秒一个来回）：数好节奏再穿越，45 米高空门（12m 以上）+3，55 米过关。更多机制关卡（用户指令扩展）"},
	{name = "第 12 关 · 乘风摆门", short = "乘风摆门", ratio = 0.9, folds = 6, target_m = 60.0, wind = "side", wind_side = 1.0, reward = 12,
		gate_x = 40.0, gate_h = 12.0, gate_bonus = 3, gate_swing = 360.0, gate_period = 4.0,
		tip = "侧风向右推，门横位还在 ±6m 摆动（4 秒来回）：乘风向右漂，数准门的节奏，40 米高空门（12m 以上）+3，60 米过关。更多机制关卡（用户指令扩展）"},
	{name = "第 13 关 · 三风交汇", short = "三风交汇", ratio = 0.85, folds = 6, target_m = 55.0, wind = "head", side_wind = -60.0, reward = 14,
		gate_x = 42.0, gate_h = 12.0, gate_bonus = 3, gate_side = 180.0, gate_swing = 300.0, gate_period = 2.5,
		tip = "三风交汇：逆风阻力 1.25 倍、侧风向左推（60px/s²），门横位还在 +3m 上 ±5m 摆动（2.5 秒来回）——顶住左漂向右切，数准门摆节奏，42 米高空门（12m 以上）+3，55 米过关。更多机制关卡（用户指令扩展）"},
	{name = "第 14 关 · 逆风三段走廊", short = "逆风三段", ratio = 0.85, folds = 6, target_m = 70.0, wind = "head", side_wind = -60.0, shear_x = 35.0, shear_x2 = 60.0, reward = 14,
		gate_x = 48.0, gate_h = 12.0, gate_bonus = 3, gate_side = 120.0,
		tip = "逆风 1.25 倍 + 三段侧风：35 米前左漂、35-60 米右送（趁势吃 48 米高空门 +4m 横位 +3）、60 米后再左漂收尾 70 米。更多机制关卡（用户指令扩展）"},
	{name = "第 15 关 · 三段侧风", short = "三段侧风", ratio = 0.9, folds = 6, target_m = 65.0, wind = "head", side_wind = 60.0, shear_x = 30.0, shear_x2 = 50.0, reward = 14,
		gate_x = 42.0, gate_h = 12.0, gate_bonus = 3, gate_side = -240.0,
		tip = "逆风 1.25 倍 + 三段侧风：30 米前右送、30-50 米左拽（顺势向左切，42 米高空门在 -4m 横位 +3）、50 米后右送收尾 65 米。更多机制关卡（用户指令扩展）"},
	{name = "第 16 关 · 逆风摆门峡", short = "逆风摆门峡", ratio = 0.85, folds = 6, target_m = 80.0, wind = "side", wind_side = -1.0, shear_x = 32.0, wind_side2 = 1.0, shear_x2 = 58.0, wind_side3 = -1.0, reward = 14,
		gate_x = 46.0, gate_h = 12.0, gate_bonus = 3, gate_side = 240.0, gate_swing = 300.0, gate_period = 3.5,
		tip = "双段切变 + 摆门：32 米前左风、32-58 米右风（门横位还在 +4m 上 ±5m 摆动，3.5 秒来回）——乘风右切吃 46 米高空门 +3，58 米后左风收尾 80 米。更多机制关卡（用户指令扩展）"},
	{name = "第 17 关 · 摆门斜风", short = "摆门斜风", ratio = 0.9, folds = 6, target_m = 60.0, wind = "head", side_wind = -60.0, reward = 14,
		gate_x = 44.0, gate_h = 12.0, gate_bonus = 3, gate_side = 300.0, gate_swing = 240.0, gate_period = 4.0,
		tip = "斜风摆门：逆风 1.25 倍 + 侧风向左推（60px/s²），门横位在 +5m 上 ±4m 摆动（4 秒来回）——顶住左漂向右切，对准门的摆位，44 米高空门（12m 以上）+3，60 米过关。更多机制关卡（用户指令扩展）"},
	{name = "第 18 关 · 低空摆门", short = "低空摆门", ratio = 0.9, folds = 6, target_m = 60.0, wind = "none", reward = 12,
		gate_x = 40.0, gate_h = 12.0, gate_bonus = 3, gate_swing = 240.0, gate_period = 3.0, low_gate_x = 44.0, low_gate_top = 10.0, low_gate_swing = 300.0, low_gate_period = 3.0,
		tip = "两扇门都在摆！高门中线 ±4m 摆动，低门 44 米处横位 ±5m 摆动（3 秒来回）——走高门看准摆位，俯冲吃低门要看它摆到哪，一掷二选一，60 米过关。更多机制关卡（用户指令扩展）"},
	{name = "第 19 关 · 逆风S形摆门", short = "逆风S形", ratio = 0.8, folds = 6, target_m = 70.0, wind = "head", side_wind = -60.0, shear_x = 30.0, shear_x2 = 55.0, reward = 14,
		gate_x = 45.0, gate_h = 12.0, gate_bonus = 3, gate_side = 240.0, gate_swing = 300.0, gate_period = 4.0,
		tip = "逆风 1.25 倍 + 双段切变侧风：30 米前左漂、30-55 米右送（趁势吃 45 米摆动高门 +3）、55 米后左漂收尾 70 米。更多机制关卡（用户指令扩展）"},
	{name = "第 20 关 · 切变低门", short = "切变低门", ratio = 0.85, folds = 6, target_m = 60.0, wind = "none", side_wind = 60.0, shear_x = 30.0, shear_x2 = 50.0, reward = 14,
		gate_x = 44.0, gate_h = 12.0, gate_bonus = 3, gate_swing = 240.0, gate_period = 3.5, low_gate_x = 48.0, low_gate_top = 10.0, low_gate_swing = 240.0, low_gate_period = 3.5, low_gate_side = 0.0,
		tip = "双段切变 + 双摆门：30 米前右送、30-50 米左拽、50 米后右送；高门 44 米固定，低门 48 米横位 ±4m 摆动（3.5 秒来回）——左拽段俯冲向左切吃低门 +3，一掷二选一，60 米过关。更多机制关卡（用户指令扩展）"},
	{name = "第 21 关 · 顺风摆门", short = "顺风摆门", ratio = 0.85, folds = 6, target_m = 70.0, wind = "tail", reward = 14,
		gate_x = 50.0, gate_h = 12.0, gate_bonus = 3, low_gate_x = 55.0, low_gate_top = 10.0, low_gate_swing = 240.0, low_gate_period = 3.0, low_gate_side = 120.0,
		tip = "顺风 + 摆动低门：顺风推你加速，低门 55 米处横位 +2m 上 ±4m 摆动（3 秒来回）——顺风冲到低门位置时看准它摆到哪，俯冲穿越 +3，一掷二选一，70 米过关。更多机制关卡（用户指令扩展）"},
	{name = "第 22 关 · 顺风斜风", short = "顺风斜风", ratio = 0.85, folds = 6, target_m = 65.0, wind = "tail", side_wind = 60.0, reward = 14,
		gate_x = 42.0, gate_h = 12.0, gate_bonus = 3, gate_side = -240.0,
		tip = "顺风斜风：顺风恒推让你冲得更快，侧风又向右推（60px/s²）——高门 42 米却在左边（-4m 横位、12m 以上）+3：提前按住 A 顶风左切，飞得越快修正窗口越短，65 米过关。更多机制关卡（用户指令扩展）"},
	{name = "第 23 关 · 顺风S形", short = "顺风S形", ratio = 0.85, folds = 6, target_m = 70.0, wind = "tail", side_wind = -60.0, shear_x = 30.0, shear_x2 = 55.0, reward = 14,
		gate_x = 45.0, gate_h = 12.0, gate_bonus = 3, gate_side = 240.0,
		tip = "顺风S形：顺风恒推冲得快，侧风先左后右再左（30/55 米两次切变）——中段乘风右切吃 45 米高空门（+4m 横位、12m 以上）+3，末段左风帮你回正收尾 70 米。更多机制关卡（用户指令扩展）"},
	{name = "第 24 关 · 下沉峡谷", short = "下沉峡谷", ratio = 0.6, folds = 6, target_m = 75.0, wind = "head", wind_up = -1600.0, wind_up_x = 50.0, wind_up_len = 20.0, reward = 14,
		gate_x = 30.0, gate_h = 14.0, gate_bonus = 3, low_gate_x = 72.0, low_gate_top = 12.0,
		tip = "下沉峡谷：逆风阻力 1.25 倍，50-70 米有一段猛烈下沉气流压你的高度——平折低抛（约 26°）被气流压到 72 米低空门（12m 以下）+3，抬头一点（27-32°）吃 30 米高空门（14m 以上）+3 但会从低门上方飘过——一掷二选一靠出手角度选择，75 米过关。新机制关（用户指令扩展）"},
	{name = "第 25 关 · 热气流救援", short = "热气流救援", ratio = 0.6, folds = 6, target_m = 80.0, wind = "head", wind_up = -2500.0, wind_up_x = 40.0, wind_up_len = 12.0, wind_up2 = 3000.0, wind_up2_x = 54.0, wind_up2_len = 16.0, reward = 14,
		gate_x = 72.0, gate_h = 18.0, gate_bonus = 3,
		tip = "热气流救援：逆风 80 米，40-52 米下沉谷会把你压下去——没有 54-70 米的热气流托一把，谁都滑不到终点也够不着 72 米高空门（18m 以上）+3。带着谷底攒下的俯冲速度冲进热流爬升，出口高度决定吃不吃门。新机制关（用户指令扩展）"},
	{name = "第 26 关 · 谷底摆门", short = "谷底摆门", ratio = 0.6, folds = 6, target_m = 70.0, wind = "head", wind_up = -2000.0, wind_up_x = 40.0, wind_up_len = 12.0, reward = 14,
		gate_x = 30.0, gate_h = 14.0, gate_bonus = 3, low_gate_x = 58.0, low_gate_top = 10.0, low_gate_swing = 420.0, low_gate_period = 3.0,
		tip = "谷底摆门：逆风 70 米，40-52 米下沉谷把低线压到 10m 以下——58 米低空门还在横摆（±7m、3 秒来回）+3，俯冲穿谷还得数准它摆到哪；抬头吃 30 米高空门（14m 以上）+3 则完全不同路。一掷二选一，70 米过关。新机制关（用户指令扩展）"},
	{name = "第 27 关 · 热流摆门", short = "热流摆门", ratio = 0.6, folds = 6, target_m = 80.0, wind = "head", wind_up = -2500.0, wind_up_x = 40.0, wind_up_len = 12.0, wind_up2 = 3000.0, wind_up2_x = 54.0, wind_up2_len = 16.0, reward = 14,
		gate_x = 74.0, gate_h = 18.0, gate_bonus = 3, gate_swing = 420.0, gate_period = 3.5,
		tip = "热流摆门：逆风 80 米，先沉后托（40-52 米谷、54-70 米热流）——爬出热流的出口高度决定你够不够得着 74 米摆动高门（18m 以上、±7m、3.5 秒来回）+3：能量与门位双时序，冲得早不如冲得巧，80 米过关。新机制关（用户指令扩展）"},
	{name = "第 28 关 · 谷风低门", short = "谷风低门", ratio = 0.6, folds = 6, target_m = 65.0, wind = "head", side_wind = 60.0, wind_up = -2000.0, wind_up_x = 36.0, wind_up_len = 10.0, reward = 14,
		gate_x = 28.0, gate_h = 14.0, gate_bonus = 3, low_gate_x = 52.0, low_gate_top = 8.0, low_gate_side = 240.0,
		tip = "谷风低门：逆风加右推侧风（60px/s²），36-46 米下沉谷把低线压到 8m 以下——谷底正好是侧风把你送进 52 米右侧低空门（+4m 横位、8m 以下）+3 门带的时机，切忌补舵（按 D 冲过头、按 A 被带出带）；抬头线先吃 28 米高空门（14m 以上）+3。一掷二选一，65 米过关。新机制关（用户指令扩展）"},
	{name = "第 29 关 · 双谷接力", short = "双谷接力", ratio = 0.6, folds = 6, target_m = 62.0, wind = "head", wind_up = -1400.0, wind_up_x = 30.0, wind_up_len = 10.0, wind_up2 = -1400.0, wind_up2_x = 50.0, wind_up2_len = 10.0, reward = 14,
		gate_x = 24.0, gate_h = 14.0, gate_bonus = 3, low_gate_x = 46.0, low_gate_top = 21.0,
		tip = "双谷接力：逆风 62 米有两段下沉谷（30-40 米、50-60 米）——高度要省着用：先吃 24 米高空门（14m 以上）+3，或平折线从第一谷出来在 40-50 米喘息窗口吃 46 米低空门（14m 以下）+3，闯过第二谷收 62 米。两谷三站一掷到底。新机制关（用户指令扩展）"},
	{name = "第 30 关 · 终局峡谷", short = "终局峡谷", ratio = 0.6, folds = 6, target_m = 70.0, wind = "head", side_wind = -60.0, wind_up = -1600.0, wind_up_x = 36.0, wind_up_len = 8.0, wind_up2 = 2400.0, wind_up2_x = 48.0, wind_up2_len = 12.0, reward = 14,
		gate_x = 66.0, gate_h = 16.0, gate_bonus = 3, gate_side = -240.0,
		tip = "终局峡谷：全机制终考——逆风 1.25 倍、左推侧风（60px/s²）、36-44 米下沉谷压你下去、48-60 米热气流把你托回来，出口高度够不够得着 66 米左侧高空门（-4m 横位、16m 以上）+3：谷里被压多低、热流里爬多高、风替你漂多左，三件事拼成最后一掷，70 米冲线。新机制关（用户指令扩展）"},
	{name = "第 31 关 · 风暴回廊", short = "风暴回廊", ratio = 0.6, folds = 6, target_m = 76.0, wind = "head", side_wind = 60.0, wind_up = -2200.0, wind_up_x = 30.0, wind_up_len = 10.0, wind_up2 = 2800.0, wind_up2_x = 44.0, wind_up2_len = 14.0, reward = 14,
		gate_x = 62.0, gate_h = 16.0, gate_bonus = 3, gate_side = 300.0, gate_swing = 360.0, gate_period = 3.0,
		tip = "风暴回廊（大师篇）：机制全叠的进阶挑战——逆风 1.25 倍、右推侧风、30-40 米深谷把你砸下去、44-58 米热气流再托回来，爬出热流还要够得着 62 米摆动高门（+5m 横位、16m 以上、±6m、3 秒来回）+3：能量、漂移、门相三重时序，76 米冲线。大师关（用户指令扩展）"},
	{name = "第 32 关 · 狂风精准", short = "狂风精准", ratio = 0.6, folds = 6, target_m = 66.0, wind = "head", side_wind = 120.0, reward = 14,
		gate_x = 44.0, gate_h = 12.0, gate_bonus = 3, gate_side = 700.0,
		tip = "狂风精准（大师篇）：双倍侧风（120px/s²）全系列最横——44 米高空门（12m 以上）挂在 +12m 横位远右，只有全帆乘风让风把你送去才够得着：管住手别打舵、也千万别买侧翼配重（它让你漂不到那儿）+3。乘风课的对偶面——强项要看场合，66 米冲线。大师关（用户指令扩展）"},
	{name = "第 33 关 · 热流之巅", short = "热流之巅", ratio = 0.6, folds = 6, target_m = 74.0, wind = "head", wind_up = -2200.0, wind_up_x = 34.0, wind_up_len = 10.0, wind_up2 = 3200.0, wind_up2_x = 46.0, wind_up2_len = 14.0, reward = 14,
		gate_x = 60.0, gate_h = 24.0, gate_bonus = 3,
		tip = "热流之巅（大师篇）：竖直风的精确高度课——34-44 米深谷砸你到底，46-60 米强热流把你抛回来，而 60 米高空门挂在 24m 以上（全系列最高门）+3：谷底攒的俯冲速度就是热流里的燃料，骑得越正抛得越高，够不着就是骑歪了。74 米冲线。大师关（用户指令扩展）"},
	{name = "第 34 关 · 配重峡", short = "配重峡", ratio = 0.6, folds = 6, target_m = 70.0, wind = "head", side_wind = 120.0, reward = 14,
		gate_x = 46.0, gate_h = 12.0, gate_bonus = 3, gate_side = -660.0,
		tip = "配重峡（大师篇）：顶风马拉松——双倍侧风（120px/s²）全程把你往右推，46 米高空门（12m 以上）挂在 -11m 横位极左：从起跳到冲线按住 A 不松手才顶得到 +3，一松手就被风带走。侧翼配重给你余量（1 级从容、2 级宽裕），但顶风的意志才是门票。70 米冲线。大师关（用户指令扩展）"},
	{name = "第 35 关 · 终幕回廊", short = "终幕回廊", ratio = 0.6, folds = 6, target_m = 80.0, wind = "head", side_wind = -60.0, wind_up = -2000.0, wind_up_x = 30.0, wind_up_len = 8.0, wind_up2 = 2800.0, wind_up2_x = 42.0, wind_up2_len = 10.0, reward = 14,
		gate_x = 60.0, gate_h = 18.0, gate_bonus = 3, gate_side = -240.0, gate_swing = 360.0, gate_period = 3.0,
		tip = "终幕回廊（大师篇）：最终试炼——逆风 1.25 倍、左推侧风、30-38 米深谷、42-52 米热气流，尽头是 60 米摆动高门（18m 以上、-4m 上 ±6m 摆、3 秒来回）+3：能量、漂移、门相全时序收于一掷，80 米冲线。大师关（用户指令扩展）"},
	{name = "第 36 关 · 时机走廊", short = "时机走廊", ratio = 0.7, folds = 5, target_m = 60.0, wind = "none", reward = 14,
		gate_x = 40.0, gate_h = 12.0, gate_bonus = 3, gate_open_t0 = 2.0, gate_open_t1 = 3.2,
		tip = "时机走廊（大师篇）：新门类型——40 米高空门（12m 以上）只在 2.0-3.2 秒的时间窗内存在：扔太快门还没开，太慢门已经关。折线定弧线、弧线定到达时刻，把穿越掐进窗里 +3。无风纯时序考，60 米冲线。新门类型（用户指令扩展）"},
	{name = "第 37 关 · 俯冲峡", short = "俯冲峡", ratio = 0.7, folds = 5, target_m = 78.0, wind = "none", reward = 14,
		low_gate_x = 70.0, low_gate_top = 21.0, gate_bonus = 3,
		tip = "俯冲峡（大师篇）：新输入课——70 米低空门（21m 以下）+3 藏在你的自然滑翔高度之下：2 秒后按住 S 俯冲压低才能穿门，不俯冲冲线也没门奖。新输入 S 键，俯冲时机与压低深度全凭手感，78 米冲线。新输入（用户指令扩展）"},
	{name = "第 38 关 · 俯冲摆门", short = "俯冲摆门", ratio = 0.7, folds = 5, target_m = 74.0, wind = "none", reward = 14,
		low_gate_x = 66.0, low_gate_top = 12.0, low_gate_side = 0.0, low_gate_swing = 360.0, low_gate_period = 3.0, gate_bonus = 3,
		tip = "俯冲摆门（大师篇）：双时序复合课——66 米低空门（12m 以下）既在下沉等待俯冲，又在 ±6m 横摆：按 S 的时机定高度，门的相位定横位，两个节奏对上才穿得过 +3。先定俯冲点再对拍子，74 米冲线。大师关（用户指令扩展）"},
	{name = "第 39 关 · 俯冲侧峡", short = "俯冲侧峡", ratio = 0.7, folds = 5, target_m = 72.0, wind = "head", side_wind = -60.0, reward = 14,
		low_gate_x = 52.0, low_gate_top = 18.0, low_gate_side = 240.0, gate_bonus = 3,
		tip = "俯冲侧峡（大师篇）：双操作课——52 米低空门（18m 以下）挂在 +4m 横位，左推侧风（60px/s²）却把你往左带：自然滑翔高度在门顶之上，按住 S 俯冲压低、同时按 D 顶风右靠，两键同按才穿得过 +3。垂直与横向双操作，72 米冲线。大师关（用户指令扩展）"},
]

const SHOP_POOL := [
	{id = "power", name = "力气", price = 3, desc = "投掷力度上限 +20%，可叠加"},
	{id = "wing", name = "翼面加强", price = 4, desc = "机翼升力面积 +15%，可叠加"},
	{id = "prop", name = "螺旋桨", price = 6, unique = true, desc = "沿机头方向的恒定推力，唯一"},
	{id = "trimtool", name = "配平仪", price = 4, unique = true, desc = "配平对俯仰的影响减半，唯一"},
	{id = "stiff", name = "纸面加固", price = 4, desc = "折线阻力 -15%/级，可叠加"},
	{id = "ballast", name = "重心铅条", price = 5, desc = "配平收敛 30%/级（狂野折法变温顺），可叠加"},
	{id = "tough", name = "韧性", price = 3, unique = true, desc = "落地弹跳一次不直接判负，唯一"},
	{id = "sideweight", name = "侧翼配重", price = 4, desc = "侧风推力 -25%/级，可叠加"},
	{id = "anemo", name = "气流计", price = 3, unique = true, desc = "风标签显示精确数值（px/s²），唯一"},
]

## C37 打磨：七物机制适配提示（选关/商店帮助玩家按当前关机制选购物）
const SHOP_HINTS := {
	"power": "长距离关利器",
	"wing": "滑翔关/高门关通用",
	"prop": "平飞稳定，侧风关好搭档",
	"trimtool": "精确切门必备",
	"stiff": "逆风关利器（降阻力）",
	"sideweight": "侧风关利器（抗漂移）",
	"anemo": "读风入门（数值党）",
	"ballast": "摆门关好搭档（驯配平）",
	"tough": "低空关门保底",
}


func shop_hint(id: String) -> String:
	return String(SHOP_HINTS.get(id, ""))

## 跑局经济（跨关持续）
var rng := RandomNumberGenerator.new()
var state := "menu"          # menu / fold / throw / fly / settle / shop / final
var level_idx := 0
var unlocked := 0
var coins := 0
var upgrades := {power = 0, wing = 0, stiff = 0, ballast = 0, sideWeight = 0}   # 可叠加强化级数（C4 纸面加固 / C7 重心铅条 / C60 侧翼配重）
var owned := []
var shop_items := []
var total_distance := 0.0
var best_distance := 0.0
var gates_offered := 0   # C54 打磨：本趟出现过的门总数（终局面板吃门统计，每关首次进入计一次）
var gates_eaten := 0     # 本趟吃下的门数（门奖结算点累计；重试已吃门计入 N 不计入 M）
var offered_mark := -1   # 去重标记：start_level 同关重入（失败重试）不重复累计 offered

## 本关折纸
var paper_rect := Rect2(90, GROUND_Y - 300.0, 420.0, 300.0)
var folds := []
var folds_used := 0
var plane_params := {lift_area = 0.0, trim = 0.0, drag_f = 0.0}
var throw_angle := 30.0

## 本掷飞行
var plane_pos := Vector2(START_X, GROUND_Y - 40.0)
var velocity := Vector2.ZERO
var pitch := 0.0
var eff_lift := 0.0
var eff_drag_f := 0.0        # C4：投掷时定格的有效折线阻力（含纸面加固）
var eff_trim := 0.0          # C7：投掷时定格的有效配平（含重心铅条收敛；angle_forgive 仍用原配平）
var flight_time := 0.0
var flight_distance := 0.0
var apex_m := 0.0
var gate_hit := false
var low_gate_hit := false
var angle_forgive := 0.0
var sample_acc := 0.0
var bounced := false
var gate_coins := 0          # 新增：本掷门奖（显示拆分用，不改到账规则）
var trail := []

## 阶段 B1：横向状态（+右，px；表现层换算米）
var lateral := 0.0
var lateral_vel := 0.0
var lateral_input := 0.0     # -1/0/+1（A/D），由表现层输入事件设置
var dive_input := false      # C88 新输入（规则变化）：飞行中 S/↓ 俯冲，表现层输入事件设置

## 结算
var last_pass := false
var coins_earned := 0


## 视觉偏航（表现层用）：横移相对前进速度的航向角，rad
func yaw_rad() -> float:
	return atan2(-lateral_vel, maxf(velocity.length(), 80.0))


func level_count() -> int:
	return LEVELS.size()


func level_dict() -> Dictionary:
	return LEVELS[level_idx]


func start_level(i: int) -> void:
	if i < 0 or i >= LEVELS.size():
		return
	level_idx = i
	if i != offered_mark:   # C54：同关重试重入不重复计门
		offered_mark = i
		gates_offered += (1 if float(LEVELS[i].get("gate_x", 0.0)) > 0.0 else 0) + (1 if float(LEVELS[i].get("low_gate_x", 0.0)) > 0.0 else 0)
	var ph := 300.0
	var pw := ph * float(LEVELS[i].ratio)
	paper_rect = Rect2(90, GROUND_Y - ph, pw, ph)
	folds = []
	folds_used = 0
	plane_params = {lift_area = 0.0, trim = 0.0, drag_f = 0.0}
	throw_angle = 30.0
	plane_pos = Vector2(START_X, GROUND_Y - 40.0)
	velocity = Vector2.ZERO
	pitch = 0.0
	eff_lift = 0.0
	flight_time = 0.0
	flight_distance = 0.0
	apex_m = 0.0
	gate_hit = false
	low_gate_hit = false
	angle_forgive = 0.0
	sample_acc = 0.0
	bounced = false
	gate_coins = 0
	last_pass = false
	coins_earned = 0
	trail = []
	lateral = 0.0
	lateral_vel = 0.0
	state = "fold"


## 折一条线：p1/p2 为纸面所在坐标系的全局坐标，两点都需落在放宽 10px 的纸面内。
func add_fold(p1: Vector2, p2: Vector2) -> bool:
	if state != "fold" or folds_used >= int(LEVELS[level_idx].folds):
		return false
	if not paper_rect.grow(FOLD_TOLERANCE).has_point(p1) or not paper_rect.grow(FOLD_TOLERANCE).has_point(p2):
		return false
	folds.append([p1, p2])
	folds_used += 1
	var lp1 := p1 - paper_rect.position
	var lp2 := p2 - paper_rect.position
	var mid := (lp1 + lp2) * 0.5
	var out := clampf(mid.x / paper_rect.size.x, 0.0, 1.0)
	var vert := clampf((paper_rect.size.y * 0.5 - mid.y) / (paper_rect.size.y * 0.5), -1.0, 1.0)
	var len_c := clampf(lp1.distance_to(lp2) / paper_rect.size.length(), 0.0, 1.0)
	apply_fold_params(out, vert, len_c)
	return true


## 归一折线参数入口（3D 折纸 UI 用）：out=横向 0..1（右=外），vert=-1..1（上正），len_c=长度比 0..1
func apply_fold_params(out: float, vert: float, len_c: float) -> void:
	plane_params.lift_area = float(plane_params.lift_area) + LIFT_PER_FOLD * (0.4 + 0.6 * out)
	plane_params.trim = float(plane_params.trim) + TRIM_PER_FOLD * vert
	plane_params.drag_f = float(plane_params.drag_f) + DRAG_PER_FOLD * len_c


func finish_folds() -> void:
	if state == "fold":
		state = "throw"


## 投掷：angle_deg 0..60（度），power 0..1（实际截到 0.05..1）。
func do_throw(angle_deg: float, power: float) -> void:
	if state != "throw":
		return
	throw_angle = clampf(angle_deg, 0.0, 60.0)
	var pw: float = clampf(power, 0.05, 1.0)
	var v0: float = LAUNCH_V * pw * power_mult()
	eff_lift = float(plane_params.lift_area) * wing_mult()
	eff_drag_f = float(plane_params.drag_f) * stiff_mult()
	# C7：配平收敛（仅影响飞行性格 lift_tilt/俯仰偏置；angle_forgive 窗口仍按折线原配平）
	eff_trim = float(plane_params.trim) * ballast_mult()
	velocity = Vector2.from_angle(-deg_to_rad(throw_angle)) * v0
	pitch = -deg_to_rad(throw_angle)
	plane_pos = Vector2(START_X, GROUND_Y - 40.0)
	flight_time = 0.0
	flight_distance = 0.0
	apex_m = 0.0
	gate_hit = false
	low_gate_hit = false
	# 稳定型容错：配平在稳定区且投掷角接近 40° 最优时，阻力降低（角误差 ±5° 内线性衰减到零）
	var ang_err: float = absf(throw_angle - 40.0)
	var t_st: float = float(plane_params.trim)
	angle_forgive = 0.0
	if t_st >= -0.15 and t_st <= 0.35:
		angle_forgive = 0.2 * clampf(1.0 - ang_err / 5.0, 0.0, 1.0)
	sample_acc = 0.0
	bounced = false
	gate_coins = 0
	last_pass = false
	coins_earned = 0
	trail = [plane_pos]
	lateral = 0.0
	lateral_vel = 0.0
	state = "fly"


## 推进一步（delta 由调用方固定，建议 1/60）。返回事件：""=继续飞行，"bounce"=韧性弹跳，"finish"/"ground"/"timeout"=已结算。
func step(delta: float) -> String:
	if state != "fly":
		return ""
	flight_time += delta
	# 阶段 B1/C2/C5/C6/C13：横向独立运动学（不触碰下方旧纵向/高度积分，升力不耦合）
	# C2：wind="side" 恒定侧风（可切变）；C6：正交字段 side_wind 与 forward 风叠加；
	# C13：切变面同样作用于正交侧风——每越过一个已配置切变面，符号翻转一次（L9 无切变面 → 恒号不变）
	var wind_a: float = 0.0
	if wind_mode() == "side":
		wind_a = eff_wind_side() * LAT_WIND
	else:
		wind_a = side_wind_accel() * shear_sign_flip()
	wind_a *= wind_damp_mult()   # C60：侧翼配重按级衰减风推分量（不改玩家输入与阻尼）
	if lateral_input != 0.0 or wind_a != 0.0:
		lateral_vel += (lateral_input * LAT_ACCEL + wind_a) * delta
	else:
		var ldamp: float = LAT_DAMP * delta
		lateral_vel = 0.0 if absf(lateral_vel) <= ldamp else lateral_vel - signf(lateral_vel) * ldamp
	lateral_vel = clampf(lateral_vel, -LAT_VMAX, LAT_VMAX)
	lateral += lateral_vel * delta
	if absf(lateral) > LAT_LIMIT_PX:
		lateral = signf(lateral) * LAT_LIMIT_PX
		lateral_vel = 0.0
	var spd := velocity.length()
	var lift_up: float = minf(LIFT_K * eff_lift * spd * spd, GRAV * 0.95)
	var t_trim: float = clampf(eff_trim, -1.5, 1.5)
	var lift_scale := 1.0
	var lift_tilt: float = t_trim * 0.22
	if t_trim < -0.05:
		lift_scale = lerpf(1.0, 0.35, clampf((-t_trim - 0.05) / 0.55, 0.0, 1.0))
	elif t_trim > 0.15:
		lift_tilt = lerpf(t_trim * 0.22, 0.55, clampf((t_trim - 0.15) / 0.45, 0.0, 1.0))
	if has_upgrade("trimtool"):
		lift_tilt *= 0.5
	var lift_dir := Vector2(sin(lift_tilt), -cos(lift_tilt)).normalized()
	var drag_f_v: float = eff_drag_f
	var drag_coef := DRAG_K * (BASE_DRAG + drag_f_v)
	if wind_mode() == "head":
		drag_coef *= HEAD_DRAG_MULT
	drag_coef *= (1.0 - angle_forgive)
	var drag_vec := Vector2.ZERO
	if spd > 0.01:
		drag_vec = -velocity / spd * (drag_coef * spd * spd)
	var acc := lift_dir * (lift_up * lift_scale) + drag_vec + Vector2(0.0, GRAV)
	if wind_mode() == "tail":
		acc += Vector2(TAIL_THRUST, 0.0)
	var up_a: float = updraft_accel()
	if absf(up_a) > 0.0:
		acc += Vector2(0.0, -up_a)   # 屏幕系 y 向下：+wind_up（上升）取负
	if dive_input:
		acc += Vector2(0.0, DIVE_ACCEL)   # C88 俯冲：额外下压（屏幕系 y 向下为正）
	if has_upgrade("prop"):
		acc += Vector2.from_angle(pitch) * PROP_THRUST
	velocity += acc * delta
	var d_ang := wrapf(velocity.angle() - pitch, -PI, PI)
	pitch += (PITCH_FOLLOW * d_ang + 0.35 * clampf(eff_trim, -1.0, 1.0)) * delta
	var prev_x := plane_pos.x
	plane_pos += velocity * delta
	apex_m = maxf(apex_m, (GROUND_Y - plane_pos.y) / PX_PER_M)
	trail.append(plane_pos)
	if trail.size() > 900:  # 表现缓冲（非模拟量）：阶段 C 复盘小图需整掷轨迹，14s×60fps=840
		trail.pop_front()
	sample_acc += delta
	if sample_acc >= SAMPLE_STEP:
		sample_acc -= SAMPLE_STEP
		flight_distance = maxf(flight_distance, (plane_pos.x - START_X) / PX_PER_M)
	# 高空门：穿越门位、高度 ≥ gate_h、横向 |lateral - gate_side| ≤ GATE_HALF（B2：门横位入配置）
	# （与低空门互斥，一掷只吃其一；门奖即时入 coins、失败保留）
	var gate_x_m: float = float(LEVELS[level_idx].get("gate_x", 0.0))
	if gate_x_m > 0.0 and not gate_hit and not low_gate_hit and gate_open():
		var gate_px := START_X + gate_x_m * PX_PER_M
		if prev_x < gate_px and plane_pos.x >= gate_px:
			var gate_side: float = gate_side_at(flight_time)  # C10：含摆动项（穿越时刻的瞬时横位）
			if plane_pos.y <= GROUND_Y - float(LEVELS[level_idx].gate_h) * PX_PER_M and absf(lateral - gate_side) <= GATE_HALF_PX:
				gate_hit = true
				gates_eaten += 1
				var gb: int = int(LEVELS[level_idx].gate_bonus)
				coins += gb
				coins_earned += gb
				gate_coins += gb
	# 低空门：穿越门位、高度 ≤ low_gate_top、横向 |lateral - low_gate_side| ≤ GATE_HALF（与高空门互斥）
	var lg_x_m: float = float(LEVELS[level_idx].get("low_gate_x", 0.0))
	if lg_x_m > 0.0 and not low_gate_hit and not gate_hit:
		var lg_px := START_X + lg_x_m * PX_PER_M
		if prev_x < lg_px and plane_pos.x >= lg_px:
			var lg_side: float = low_gate_side_at(flight_time)  # C19：含低空门摆动项
			if plane_pos.y >= GROUND_Y - float(LEVELS[level_idx].low_gate_top) * PX_PER_M and absf(lateral - lg_side) <= GATE_HALF_PX:
				low_gate_hit = true
				gates_eaten += 1
				var lgb: int = int(LEVELS[level_idx].gate_bonus)
				coins += lgb
				coins_earned += lgb
				gate_coins += lgb
	# 结算优先级：终点 > 落地（韧性弹一次） > 14 秒超时
	var finish_px := START_X + float(LEVELS[level_idx].target_m) * PX_PER_M
	if plane_pos.x >= finish_px:
		settle()
		return "finish"
	if plane_pos.y >= GROUND_Y:
		if has_upgrade("tough") and not bounced:
			bounced = true
			plane_pos.y = GROUND_Y - 2.0
			velocity.y = -absf(velocity.y) * 0.5 - 60.0
			velocity.x *= 0.8
			return "bounce"
		settle()
		return "ground"
	if flight_time >= MAX_FLIGHT_TIME:
		settle()
		return "timeout"
	return ""


func settle() -> void:
	flight_distance = maxf(flight_distance, (plane_pos.x - START_X) / PX_PER_M)
	state = "settle"
	last_pass = flight_distance >= float(LEVELS[level_idx].target_m)
	total_distance += flight_distance
	best_distance = maxf(best_distance, flight_distance)
	if last_pass:
		coins_earned = int(flight_distance / 10.0) + int(LEVELS[level_idx].reward)
		coins += coins_earned
		unlocked = maxi(unlocked, mini(level_idx + 1, LEVELS.size() - 1))
	else:
		coins_earned = 0


## 结算后继续：过关 → 商店（最后一关 → final）；失败 → 重试本关。返回去向。
func settle_continue() -> String:
	if state != "settle":
		return ""
	if last_pass:
		if level_idx >= LEVELS.size() - 1:
			state = "final"
			return "final"
		enter_shop()
		return "shop"
	start_level(level_idx)
	return "retry"


func enter_shop() -> void:
	state = "shop"
	var pool := []
	for it in SHOP_POOL:
		var id: String = String(it.id)
		if bool(it.get("unique", false)) and owned.has(id):
			continue
		pool.append(it)
	# 抽池用可注入 rng（阶段 C4 修复：原全局 shuffle 使种子不可复现；概率分布不变）
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var picked: Array = pool.slice(0, 3)
	picked.sort_custom(func(a, b) -> bool: return int(a.price) < int(b.price))
	shop_items = picked


## 买第 idx 项：扣币一次、从当次列表移出；唯一物已拥有或钱不够 → false。
func buy(idx: int) -> bool:
	if state != "shop" or idx < 0 or idx >= shop_items.size():
		return false
	var item: Dictionary = shop_items[idx]
	var price: int = int(item.price)
	if coins < price:
		return false
	if bool(item.get("unique", false)) and owned.has(String(item.id)):
		return false
	coins -= price
	var id: String = String(item.id)
	if id == "power":
		upgrades.power = int(upgrades.power) + 1
	elif id == "wing":
		upgrades.wing = int(upgrades.wing) + 1
	elif id == "stiff":
		upgrades.stiff = int(upgrades.stiff) + 1
	elif id == "ballast":
		upgrades.ballast = int(upgrades.ballast) + 1
	elif id == "sideweight":
		upgrades.sideWeight = int(upgrades.get("sideWeight", 0)) + 1
	else:
		owned.append(id)
	shop_items.remove_at(idx)
	return true


func shop_skip() -> void:
	if state == "shop":
		start_level(level_idx + 1)


func reset_run() -> void:
	coins = 0
	gates_offered = 0
	gates_eaten = 0
	offered_mark = -1
	upgrades = {power = 0, wing = 0, stiff = 0, ballast = 0, sideWeight = 0}
	owned = []
	unlocked = 0
	total_distance = 0.0
	best_distance = 0.0
	state = "menu"


func power_mult() -> float:
	return 1.0 + 0.2 * float(upgrades.power)


func wing_mult() -> float:
	return 1.0 + 0.15 * float(upgrades.wing)


## 阶段 C4 新商店物品：纸面加固（每级折线阻力 -15%，下限 0.25 防负阻力）
func stiff_mult() -> float:
	return maxf(1.0 - 0.15 * float(upgrades.get("stiff", 0)), 0.25)


## 阶段 C7 新商店物品：重心铅条（每级配平收敛 30%，下限 0.1；仅影响飞行性格，angle_forgive 用原配平）
func ballast_mult() -> float:
	return maxf(1.0 - 0.3 * float(upgrades.get("ballast", 0)), 0.1)


func has_upgrade(id: String) -> bool:
	return owned.has(id)


func wind_mode() -> String:
	return String(LEVELS[level_idx].wind)


## 侧风方向（-1=向左推，+1=向右推），仅 wind="side" 时有意义
func wind_side() -> float:
	return float(LEVELS[level_idx].get("wind_side", -1.0))


## 阶段 C5/C8 风切变：越过 shear_x 后侧风切为 wind_side2；再越过 shear_x2（C8 双段，0=无）切为 wind_side3
func eff_wind_side() -> float:
	var ws: float = wind_side()
	var shear_m: float = float(LEVELS[level_idx].get("shear_x", 0.0))
	if shear_m > 0.0 and plane_pos.x >= START_X + shear_m * PX_PER_M:
		ws = wind_side2()
	var shear2_m: float = float(LEVELS[level_idx].get("shear_x2", 0.0))
	if shear2_m > 0.0 and plane_pos.x >= START_X + shear2_m * PX_PER_M:
		ws = wind_side3()
	return ws


## 切变后的侧风方向（未配置则与切变前相同）
func wind_side2() -> float:
	return float(LEVELS[level_idx].get("wind_side2", wind_side()))


## 第二次切变后的侧风方向（未配置则与第二段相同）
func wind_side3() -> float:
	return float(LEVELS[level_idx].get("wind_side3", wind_side2()))


## 阶段 C10/C19 摆动门：门横位随飞行时间正弦摆动（gate_swing 振幅 px、gate_period 周期 s；0=静止）
## 判定与场景渲染共用此函数，保证同一时刻同一横位；C19 扩展 low_gate_swing/low_gate_period（低空门独立摆动）
func gate_side_at(t: float) -> float:
	var base: float = float(LEVELS[level_idx].get("gate_side", 0.0))
	var swing: float = float(LEVELS[level_idx].get("gate_swing", 0.0))
	var period: float = float(LEVELS[level_idx].get("gate_period", 3.0))
	if swing == 0.0 or period <= 0.0:
		return base
	return base + swing * sin(TAU * t / period)


## 阶段 C19：低空门独立摆动（low_gate_swing/low_gate_period；0=静止，缺省随高门摆动参数）
func low_gate_side_at(t: float) -> float:
	var base: float = float(LEVELS[level_idx].get("low_gate_side", 0.0))
	var swing: float = float(LEVELS[level_idx].get("low_gate_swing", 0.0))
	var period: float = float(LEVELS[level_idx].get("low_gate_period", 3.0))
	if swing == 0.0 or period <= 0.0:
		return base
	return base + swing * sin(TAU * t / period)


## 阶段 C6 正交侧风（px/s²，带符号）：与 forward 风（head/tail/none）叠加，用于非 "side" 风型关卡
func side_wind_accel() -> float:
	return float(LEVELS[level_idx].get("side_wind", 0.0))


## 阶段 C84 新门类型·时机门（规则变化）：gate_open_t0/t1（秒）为高门开启时间窗；
## 两字段均 0（缺省）= 常开，既有 35 关路径不变。窗内穿越才可判定，窗外穿越视作未设门。
func gate_open() -> bool:
	var t0: float = float(LEVELS[level_idx].get("gate_open_t0", 0.0))
	var t1: float = float(LEVELS[level_idx].get("gate_open_t1", 0.0))
	if t0 <= 0.0 and t1 <= 0.0:
		return true
	if t0 > 0.0 and flight_time < t0:
		return false
	if t1 > 0.0 and flight_time > t1:
		return false
	return true


## 阶段 C60 新商店物品·侧翼配重（规则变化）：按级 -25% 风推分量（含 side 型与正交侧风），
## 不作用于玩家横向输入与无风阻尼——买的是"抗吹"不是"抗打舵"
func wind_damp_mult() -> float:
	return 1.0 - 0.25 * float(upgrades.get("sideWeight", 0))


## 阶段 C42 新机制·气流区（规则变化）：wind_up_x（米，区起点）起 wind_up_len 米宽的竖直风带，
## wind_up（px/s²，+上升/-下沉）仅在带内生效——竖直轴风系，独立于横向（B1 不耦合）。
## C43 扩展：可选第二区带 wind_up2_x/len/wind_up（沉后托波形），两带同时命中时取和（不重叠为常规用法）
func updraft_accel() -> float:
	var total := 0.0
	var x_m: float = float(LEVELS[level_idx].get("wind_up_x", 0.0))
	if x_m > 0.0:
		var rel: float = (plane_pos.x - START_X) / PX_PER_M
		var len_m: float = float(LEVELS[level_idx].get("wind_up_len", 10.0))
		if rel >= x_m and rel < x_m + len_m:
			total += float(LEVELS[level_idx].get("wind_up", 0.0))
	var x2_m: float = float(LEVELS[level_idx].get("wind_up2_x", 0.0))
	if x2_m > 0.0:
		var rel2: float = (plane_pos.x - START_X) / PX_PER_M
		var len2_m: float = float(LEVELS[level_idx].get("wind_up2_len", 10.0))
		if rel2 >= x2_m and rel2 < x2_m + len2_m:
			total += float(LEVELS[level_idx].get("wind_up2", 0.0))
	return total


## 阶段 C13：切变面对正交侧风的符号翻转——每越过一个已配置切变面翻转一次
## （无切变面恒 +1，L9 等既有正交关卡路径不变）
func shear_sign_flip() -> float:
	var flips := 0
	var shear_m: float = float(LEVELS[level_idx].get("shear_x", 0.0))
	if shear_m > 0.0 and plane_pos.x >= START_X + shear_m * PX_PER_M:
		flips += 1
	var shear2_m: float = float(LEVELS[level_idx].get("shear_x2", 0.0))
	if shear2_m > 0.0 and plane_pos.x >= START_X + shear2_m * PX_PER_M:
		flips += 1
	return -1.0 if flips % 2 == 1 else 1.0
