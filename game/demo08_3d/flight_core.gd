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
]

const SHOP_POOL := [
	{id = "power", name = "力气", price = 3, desc = "投掷力度上限 +20%，可叠加"},
	{id = "wing", name = "翼面加强", price = 4, desc = "机翼升力面积 +15%，可叠加"},
	{id = "prop", name = "螺旋桨", price = 6, unique = true, desc = "沿机头方向的恒定推力，唯一"},
	{id = "trimtool", name = "配平仪", price = 4, unique = true, desc = "配平对俯仰的影响减半，唯一"},
	{id = "stiff", name = "纸面加固", price = 4, desc = "折线阻力 -15%/级，可叠加"},
	{id = "tough", name = "韧性", price = 3, unique = true, desc = "落地弹跳一次不直接判负，唯一"},
]

## 跑局经济（跨关持续）
var rng := RandomNumberGenerator.new()
var state := "menu"          # menu / fold / throw / fly / settle / shop / final
var level_idx := 0
var unlocked := 0
var coins := 0
var upgrades := {power = 0, wing = 0, stiff = 0}   # 可叠加强化级数（C4 加纸面加固）
var owned := []
var shop_items := []
var total_distance := 0.0
var best_distance := 0.0

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
	# 阶段 B1/C2：横向独立运动学（不触碰下方旧纵向/高度积分，升力不耦合）
	# C2 新增：wind="side" 时叠加恒定侧风加速度（方向 wind_side）；无侧风关卡路径与 B1 逐位一致
	var wind_a: float = 0.0
	if wind_mode() == "side":
		wind_a = wind_side() * LAT_WIND
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
	var t_trim: float = clampf(float(plane_params.trim), -1.5, 1.5)
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
	if has_upgrade("prop"):
		acc += Vector2.from_angle(pitch) * PROP_THRUST
	velocity += acc * delta
	var d_ang := wrapf(velocity.angle() - pitch, -PI, PI)
	pitch += (PITCH_FOLLOW * d_ang + 0.35 * clampf(float(plane_params.trim), -1.0, 1.0)) * delta
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
	if gate_x_m > 0.0 and not gate_hit and not low_gate_hit:
		var gate_px := START_X + gate_x_m * PX_PER_M
		if prev_x < gate_px and plane_pos.x >= gate_px:
			var gate_side: float = float(LEVELS[level_idx].get("gate_side", 0.0))
			if plane_pos.y <= GROUND_Y - float(LEVELS[level_idx].gate_h) * PX_PER_M and absf(lateral - gate_side) <= GATE_HALF_PX:
				gate_hit = true
				var gb: int = int(LEVELS[level_idx].gate_bonus)
				coins += gb
				coins_earned += gb
				gate_coins += gb
	# 低空门：穿越门位、高度 ≤ low_gate_top、横向 |lateral - low_gate_side| ≤ GATE_HALF（与高空门互斥）
	var lg_x_m: float = float(LEVELS[level_idx].get("low_gate_x", 0.0))
	if lg_x_m > 0.0 and not low_gate_hit and not gate_hit:
		var lg_px := START_X + lg_x_m * PX_PER_M
		if prev_x < lg_px and plane_pos.x >= lg_px:
			var lg_side: float = float(LEVELS[level_idx].get("low_gate_side", 0.0))
			if plane_pos.y >= GROUND_Y - float(LEVELS[level_idx].low_gate_top) * PX_PER_M and absf(lateral - lg_side) <= GATE_HALF_PX:
				low_gate_hit = true
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
	else:
		owned.append(id)
	shop_items.remove_at(idx)
	return true


func shop_skip() -> void:
	if state == "shop":
		start_level(level_idx + 1)


func reset_run() -> void:
	coins = 0
	upgrades = {power = 0, wing = 0, stiff = 0}
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


func has_upgrade(id: String) -> bool:
	return owned.has(id)


func wind_mode() -> String:
	return String(LEVELS[level_idx].wind)


## 侧风方向（-1=向左推，+1=向右推），仅 wind="side" 时有意义
func wind_side() -> float:
	return float(LEVELS[level_idx].get("wind_side", -1.0))
