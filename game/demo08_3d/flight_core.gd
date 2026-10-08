class_name Demo08FlightCore
extends RefCounted
## Five calibrated physical-paper challenges. Scene flight uses PaperFlight in SI units.
## Legacy distance/HUD adapter and the pure 2D fallback remain isolated below.

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
	{name = "第 1 关 · 折出机翼", short = "折出机翼", ratio = 0.7, folds = 8, target_m = 12.0, wind = "none", reward = 0,
		tip = "先点示范纸飞机，观察五步翻折；12°、满力飞过 12 米。也能自行画折痕，回退后重折"},
	{name = "第 2 关 · 低抛更远", short = "低抛更远", ratio = 0.7, folds = 8, target_m = 16.0, wind = "none", reward = 0,
		tip = "目标 16 米：示范折法，8°—15° 满力；抬得太高会失速，并不一定飞得更远"},
	{name = "第 3 关 · 顶住逆风", short = "顶住逆风", ratio = 0.7, folds = 8, target_m = 9.0, wind = "head", wind_mps = 2.0, reward = 0,
		tip = "2 米/秒逆风：示范折法，12° 满力；风改变相对气流与升阻力，目标 9 米"},
	{name = "第 4 关 · 侧风漂移", short = "侧风漂移", ratio = 0.7, folds = 8, target_m = 13.0, wind = "side", wind_side = 1.0, wind_mps = 1.5, reward = 0,
		tip = "右侧风 1.5 米/秒：示范折法，12° 满力，目标 13 米；试着轻点 A 倾斜左转，观察侧向轨迹"},
	{name = "第 5 关 · 顺风投递", short = "顺风投递", ratio = 0.7, folds = 8, target_m = 20.0, wind = "tail", wind_mps = 2.0, reward = 0,
		tip = "2 米/秒顺风：示范折法，12° 满力，目标 20 米。完成五关后可返回自由折纸试飞"},
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
var physical_trial := false
var physical_flight = null
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
var world_trail := PackedVector3Array()

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
	physical_flight = null
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
	lateral = 0.0
	lateral_vel = 0.0
	lateral_input = 0.0
	dive_input = false   # C89 修复：进关清空横向/俯冲残留（此前上一关末态会泄入新一关）
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
	world_trail.clear()
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
	var prev_x := plane_pos.x
	if physical_flight != null:
		var air := Vector3.ZERO
		if wind_mode() == "head": air.z = float(LEVELS[level_idx].get("wind_mps",3.0))
		elif wind_mode() == "tail": air.z = -float(LEVELS[level_idx].get("wind_mps",3.0))
		air.x = side_wind_accel()/PX_PER_M * shear_sign_flip()
		if wind_mode() == "side": air.x = eff_wind_side()*float(LEVELS[level_idx].get("wind_mps",3.0))
		air.y = updraft_accel()/PX_PER_M
		physical_flight.step(delta,air,float(lateral_input),dive_input)
		world_trail.append(physical_flight.position)
		plane_pos = Vector2(START_X-physical_flight.position.z*PX_PER_M,GROUND_Y-physical_flight.position.y*PX_PER_M)
		velocity = Vector2(-physical_flight.velocity.z,-physical_flight.velocity.y)*PX_PER_M
		lateral = physical_flight.position.x*PX_PER_M
		lateral_vel = physical_flight.velocity.x*PX_PER_M
		pitch = -asin(clampf(-physical_flight.orientation.z.y,-1,1))
	else:
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
	if lg_x_m > 0.0 and not low_gate_hit and not gate_hit and low_gate_open():
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
	var finish_px := INF if physical_trial else START_X + float(LEVELS[level_idx].target_m) * PX_PER_M
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
	if physical_trial:
		last_pass = true
		coins_earned = 0
		return
	last_pass = flight_distance >= float(LEVELS[level_idx].target_m)
	total_distance += flight_distance
	best_distance = maxf(best_distance, flight_distance)
	if last_pass:
		coins_earned = int(flight_distance / 10.0) + int(LEVELS[level_idx].reward)
		coins += coins_earned
		unlocked = maxi(unlocked, mini(level_idx + 1, LEVELS.size() - 1))
	else:
		coins_earned = 0


## Five-level course: pass to the next fold, retry failures, finish after level five.
func settle_continue() -> String:
	if state != "settle":
		return ""
	if last_pass:
		if level_idx >= LEVELS.size() - 1:
			state = "final"
			return "final"
		start_level(level_idx+1)
		return "fold"
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


## 阶段 C89 规则扩展（规则变化）：low_gate_open_t0/t1（秒）为低门开启时间窗——
## 时机窗从高门推广到低门，与俯冲输入耦合为"俯冲深度 × 到达时机"双约束。
## 两字段均 0（缺省）= 常开，既有 37 关路径不变。
func low_gate_open() -> bool:
	var t0: float = float(LEVELS[level_idx].get("low_gate_open_t0", 0.0))
	var t1: float = float(LEVELS[level_idx].get("low_gate_open_t1", 0.0))
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
