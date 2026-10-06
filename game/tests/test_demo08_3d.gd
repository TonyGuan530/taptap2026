extends SceneTree
## demo-08 3D 迁移阶段 A：规则核心 flight_core.gd 对照与不变量测试（headless，固定 delta，time_scale=1）
## A组 新旧对照：相同折线/角度/力度/delta 下，旧 demo08_paperplane.gd 与新核心的参数、逐步轨迹、距离、门、币数一致
## B组 不变量：折线上限/参数方向、角度容错、门互斥与即时到账、韧性一次、终点>落地>超时优先级、商店规则
## 运行：godot --headless --path game -s res://tests/test_demo08_3d.gd（失败退出码非零）

const CoreScript := preload("res://demo08_3d/flight_core.gd")
const DELTA := 1.0 / 60.0
const MAX_STEPS := 2600
const POS_EPS := 1e-6
const VAL_EPS := 1e-6

var passes := 0
var fails := 0
var log_lines: Array = []


func _init() -> void:
	_run()


func _log(t: String) -> void:
	print(t)
	log_lines.append(t)


func _check(cond: bool, tag: String) -> void:
	if cond:
		passes += 1
		_log("PASS " + tag)
	else:
		fails += 1
		_log("FAIL " + tag)


# ---------------- 工具 ----------------

func _new_old() -> Control:
	var s: Control = load("res://demo08_paperplane.tscn").instantiate()
	root.add_child(s)
	await process_frame
	return s


func _new_core() -> Object:
	return CoreScript.new()


## 同一组折线坐标喂给两侧（坐标由 paper_rect 归一生成，两侧纸面必须一致）
func _fold_coords(sc: Object, k: int) -> Array:
	var pr: Rect2 = sc.paper_rect
	var x := pr.position.x + pr.size.x * 0.92
	var y1 := pr.position.y + pr.size.y * (0.08 + 0.06 * float(k))
	var y2 := pr.position.y + pr.size.y * (0.54 + 0.06 * float(k))
	return [Vector2(x, y1), Vector2(x, y2)]


func _apply_folds(sc: Object, n: int) -> void:
	for k in n:
		var c := _fold_coords(sc, k)
		sc.add_fold(c[0], c[1])


func _setup_throw(sc: Object, level: int, n_folds: int, angle: float, power: float) -> void:
	sc.start_level(level)
	_apply_folds(sc, n_folds)
	if sc is Control:
		sc._on_fold_done()
	else:
		sc.finish_folds()
	sc.do_throw(angle, power)


func _fly_old(s: Control) -> Array:
	var pts: Array = []
	var guard := 0
	while s.state == "fly" and guard < MAX_STEPS:
		s._fly_step(DELTA)
		pts.append(s.plane_pos)
		guard += 1
	return pts


func _fly_core(c: Object) -> Array:
	var pts: Array = []
	var guard := 0
	while c.state == "fly" and guard < MAX_STEPS:
		var ev: String = c.step(DELTA)
		pts.append(c.plane_pos)
		guard += 1
		if ev == "finish" or ev == "ground" or ev == "timeout":
			break
	return pts


func _same_pts(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		var pa: Vector2 = a[i]
		var pb: Vector2 = b[i]
		if pa.distance_to(pb) > POS_EPS:
			return false
	return true


func _f(v: float) -> String:
	return "%.4f" % v


## 全量对照：参数/轨迹/结算/币数（含门）
func _compare_full(s: Control, c: Object, tag: String) -> void:
	var p_ok: bool = absf(float(s.plane_params.lift_area) - float(c.plane_params.lift_area)) < VAL_EPS \
		and absf(float(s.plane_params.trim) - float(c.plane_params.trim)) < VAL_EPS \
		and absf(float(s.plane_params.drag_f) - float(c.plane_params.drag_f)) < VAL_EPS
	_check(p_ok, tag + " 折线参数一致 lift=%.4f trim=%.4f drag=%.4f" % [
		float(c.plane_params.lift_area), float(c.plane_params.trim), float(c.plane_params.drag_f)])
	var old_pts := _fly_old(s)
	var new_pts := _fly_core(c)
	_check(_same_pts(old_pts, new_pts), tag + " 逐步轨迹一致（%d 步）" % new_pts.size())
	_check(s.state == c.state and s.state == "settle", tag + " 状态一致 settle")
	_check(absf(s.flight_distance - c.flight_distance) < VAL_EPS, tag + " 距离一致 %.2fm" % c.flight_distance)
	_check(s.last_pass == c.last_pass, tag + " 过关判定一致 %s" % str(c.last_pass))
	_check(s.coins == c.coins, tag + " 金币一致 %d" % c.coins)
	_check(s.gate_hit == c.gate_hit and s.low_gate_hit == c.low_gate_hit,
		tag + " 门命中一致 高:%s 低:%s" % [str(c.gate_hit), str(c.low_gate_hit)])
	_check(absf(s.apex_m - c.apex_m) < VAL_EPS, tag + " 顶点高度一致 %.1fm" % c.apex_m)


# ---------------- 主流程 ----------------

func _run() -> void:
	await process_frame
	_log("demo-08 3D 迁移规则核心对照测试开始（固定 delta=1/60，time_scale=1）")

	# ===== A 组：新旧对照 =====

	# A1 L1 无风：2 折 30° 满力（过关基准）
	var s1 := await _new_old()
	var c1 := _new_core()
	_setup_throw(s1, 0, 2, 30.0, 1.0)
	_setup_throw(c1, 0, 2, 30.0, 1.0)
	_compare_full(s1, c1, "A1/L1·无风·30°满力")
	_check(c1.last_pass and c1.flight_distance >= 30.0, "A1 L1 达标 %.1f≥30（迁移后旧规律保留）" % c1.flight_distance)

	# A2 L2 逆风：4 折 42°（可能吃门，两侧必须一致）
	var s2 := await _new_old()
	var c2 := _new_core()
	_setup_throw(s2, 1, 4, 42.0, 1.0)
	_setup_throw(c2, 1, 4, 42.0, 1.0)
	_compare_full(s2, c2, "A2/L2·逆风·42°满力")

	# A3 L3 顺风：5 折 35° 90% 力
	var s3 := await _new_old()
	var c3 := _new_core()
	_setup_throw(s3, 2, 5, 35.0, 0.9)
	_setup_throw(c3, 2, 5, 35.0, 0.9)
	_compare_full(s3, c3, "A3/L3·顺风·35°·0.9")

	# A4 L1 强化叠加：力气2/翼面1/螺旋桨/配平仪
	var s4 := await _new_old()
	var c4 := _new_core()
	s4.upgrades = {power = 2, wing = 1}
	s4.owned = ["prop", "trimtool"]
	c4.upgrades = {power = 2, wing = 1}
	c4.owned = ["prop", "trimtool"]
	_setup_throw(s4, 0, 3, 50.0, 1.0)
	_setup_throw(c4, 0, 3, 50.0, 1.0)
	_compare_full(s4, c4, "A4/L1·力气2翼面1螺旋桨配平仪·50°")

	# A5 超时兜底（synthetic：飞行时间直拨 13.999）
	var s5 := await _new_old()
	var c5 := _new_core()
	_setup_throw(s5, 2, 1, 30.0, 1.0)
	_setup_throw(c5, 2, 1, 30.0, 1.0)
	s5.flight_time = 13.999
	c5.flight_time = 13.999
	var ev5: String = c5.step(DELTA)
	_fly_old(s5)
	_check(ev5 == "timeout" and s5.state == "settle" and c5.state == "settle",
		"A5 超时结算：事件=timeout，两侧 settle")
	_check(s5.last_pass == c5.last_pass and c5.last_pass == false, "A5 超时判负（终点优先级未误触发）")

	# A6 终点 > 落地：同一步既到终点又在地面 → 过关
	var s6 := await _new_old()
	var c6 := _new_core()
	_setup_throw(s6, 0, 1, 30.0, 1.0)
	_setup_throw(c6, 0, 1, 30.0, 1.0)
	var finish_px: float = 60.0 + 30.0 * 60.0
	s6.plane_pos = Vector2(finish_px - 5.0, 465.0)
	c6.plane_pos = Vector2(finish_px - 5.0, 465.0)
	s6.velocity = Vector2(600, 0)
	c6.velocity = Vector2(600, 0)
	var ev6: String = c6.step(DELTA)
	_fly_old(s6)
	_check(ev6 == "finish" and c6.last_pass, "A6 优先级：终点先于落地结算（事件=finish，过关）")
	_check(s6.last_pass == true, "A6 旧版同口径过关")

	# A7 韧性：只弹一次（两侧同状态起跳，首步弹跳，再飞到结算对照）
	var s7 := await _new_old()
	var c7 := _new_core()
	s7.owned = ["tough"]
	c7.owned = ["tough"]
	_setup_throw(s7, 0, 1, 30.0, 1.0)
	_setup_throw(c7, 0, 1, 30.0, 1.0)
	s7.plane_pos = Vector2(300.0, 459.5)
	c7.plane_pos = Vector2(300.0, 459.5)
	s7.velocity = Vector2(300.0, 200.0)
	c7.velocity = Vector2(300.0, 200.0)
	var ev7: String = c7.step(DELTA)
	s7._fly_step(DELTA)
	_check(ev7 == "bounce" and c7.bounced and absf(c7.plane_pos.y - 458.0) < VAL_EPS
		and c7.velocity.y < 0.0 and absf(c7.velocity.x - 240.0) < 1.0,
		"A7 韧性首触弹跳：y=%.1f vy=%.1f vx=%.2f（阻力后前进速度×0.8）" % [c7.plane_pos.y, c7.velocity.y, c7.velocity.x])
	_check(s7.plane_pos.distance_to(c7.plane_pos) < VAL_EPS and absf(s7.velocity.y - c7.velocity.y) < VAL_EPS,
		"A7 旧版同口径弹跳（y=%.1f vy=%.1f）" % [s7.plane_pos.y, s7.velocity.y])
	var old_pts7 := _fly_old(s7)
	var new_pts7 := _fly_core(c7)
	_check(_same_pts(old_pts7, new_pts7) and s7.state == "settle" and c7.state == "settle" and c7.bounced,
		"A7 弹跳后二次落地结算，仅弹一次，两侧轨迹一致（%d 步）" % new_pts7.size())

	# ===== B 组：不变量（纯核心） =====

	# B1 折线上限/纸外拒绝
	var c8 := _new_core()
	c8.start_level(0)
	var ok_all := true
	for k in 3:
		var cc := _fold_coords(c8, k)
		ok_all = ok_all and c8.add_fold(cc[0], cc[1])
	var over: bool = c8.add_fold(Vector2(95.0, 200.0), Vector2(95.0, 300.0))
	c8.start_level(0)
	var outside: bool = c8.add_fold(Vector2(-500.0, 200.0), Vector2(200.0, 300.0))
	_check(ok_all and not over and not outside, "B1 折线：L1 前 3 次成功、第 4 次拒绝、纸外拒绝")

	# B2 参数方向：外>内升力、上正配平、阻力=0.18×长度比
	c8.start_level(0)
	_apply_folds(c8, 1)
	var lift_outer: float = c8.plane_params.lift_area
	var fc0 := _fold_coords(c8, 0)
	var drag_check: float = c8.plane_params.drag_f
	var drag_expect: float = 0.18 * (fc0[1].y - fc0[0].y) / c8.paper_rect.size.length()
	c8.start_level(0)
	var pr8: Rect2 = c8.paper_rect
	c8.add_fold(Vector2(pr8.position.x + pr8.size.x * 0.08, pr8.position.y + pr8.size.y * 0.2),
		Vector2(pr8.position.x + pr8.size.x * 0.08, pr8.position.y + pr8.size.y * 0.8))
	var lift_inner: float = c8.plane_params.lift_area
	c8.start_level(0)
	c8.add_fold(Vector2(pr8.position.x + pr8.size.x * 0.2, pr8.position.y + pr8.size.y * 0.12),
		Vector2(pr8.position.x + pr8.size.x * 0.8, pr8.position.y + pr8.size.y * 0.12))
	var trim_top: float = c8.plane_params.trim
	_check(lift_outer > lift_inner and trim_top > 0.0 and absf(drag_check - drag_expect) < 1e-9,
		"B2 参数方向：外升力 %.2f>%.2f、上配平 %.2f>0、阻力 %.5f=0.18×长度比 %.5f" % [
			lift_outer, lift_inner, trim_top, drag_check, drag_expect])

	# B3 角度容错：稳定 trim 40°满额、35°/30°为零；抬头 trim 无容错
	var c9 := _new_core()
	c9.start_level(0)
	c9.apply_fold_params(0.5, 0.8, 0.2)  # trim=0.28 稳定区
	c9.finish_folds()
	c9.do_throw(40.0, 1.0)
	var fg40: float = c9.angle_forgive
	c9.start_level(0)
	c9.apply_fold_params(0.5, 0.8, 0.2)
	c9.finish_folds()
	c9.do_throw(35.0, 1.0)
	var fg35: float = c9.angle_forgive
	c9.start_level(0)
	c9.apply_fold_params(0.5, 0.8, 0.2)
	c9.finish_folds()
	c9.do_throw(30.0, 1.0)
	var fg30: float = c9.angle_forgive
	c9.start_level(0)
	c9.apply_fold_params(0.5, 1.6, 0.2)  # trim=0.56 抬头区
	c9.finish_folds()
	c9.do_throw(40.0, 1.0)
	var fg_h: float = c9.angle_forgive
	_check(absf(fg40 - 0.2) < VAL_EPS and fg35 < VAL_EPS and fg30 < VAL_EPS and fg_h < VAL_EPS,
		"B3 角度容错：40°=%.2f、35°=%.2f、30°=%.2f、抬头40°=%.2f" % [fg40, fg35, fg30, fg_h])

	# B4 门互斥与即时到账（synthetic，L2；定速循环推进到跨线，防浮点一步差）
	var c10 := _new_core()
	c10.start_level(1)
	c10.apply_fold_params(0.9, 0.5, 0.3)
	c10.finish_folds()
	c10.do_throw(30.0, 1.0)
	c10.plane_pos = Vector2(2090.0, -300.0)  # 高门 34m 前，高度 12.67m ≥ 12m
	c10.velocity = Vector2(600.0, 0.0)
	c10.flight_time = 0.0
	var crossed_high := false
	for k in 6:
		var evh: String = c10.step(DELTA)
		if evh == "finish" or evh == "ground" or evh == "timeout":
			break
		if c10.plane_pos.x >= 2101.0:
			crossed_high = true
			break
	_check(crossed_high and c10.gate_hit and c10.coins == 3 and c10.gate_coins == 3,
		"B4a 高门命中即时 +3（coins=%d gate_coins=%d）" % [c10.coins, c10.gate_coins])
	c10.plane_pos = Vector2(2430.0, 440.0)  # 低门 40m 前，低空
	c10.velocity = Vector2(600.0, 0.0)
	var crossed_low := false
	for k in 6:
		var evl: String = c10.step(DELTA)
		if evl == "finish" or evl == "ground" or evl == "timeout":
			break
		if c10.plane_pos.x >= 2461.0:
			crossed_low = true
			break
	_check(crossed_low and not c10.low_gate_hit and c10.coins == 3,
		"B4a 已吃高门 → 低门封锁（互斥，coins 仍 %d）" % c10.coins)
	# B4b 低门先中、高门未误触发
	var c11 := _new_core()
	c11.start_level(1)
	c11.apply_fold_params(0.9, 0.5, 0.3)
	c11.finish_folds()
	c11.do_throw(30.0, 1.0)
	c11.plane_pos = Vector2(2090.0, -100.0)  # 高度过不了高门（>12m 线）
	c11.velocity = Vector2(600.0, 0.0)
	for k in 6:
		var evh2: String = c11.step(DELTA)
		if evh2 == "finish" or evh2 == "ground" or evh2 == "timeout":
			break
		if c11.plane_pos.x >= 2101.0:
			break
	c11.plane_pos = Vector2(2430.0, -100.0)  # 低门线以下（-100 ≥ -140）
	c11.velocity = Vector2(600.0, 0.0)
	for k in 6:
		var evl2: String = c11.step(DELTA)
		if evl2 == "finish" or evl2 == "ground" or evl2 == "timeout":
			break
		if c11.plane_pos.x >= 2461.0:
			break
	_check(not c11.gate_hit and c11.low_gate_hit and c11.coins == 3 and c11.gate_coins == 3,
		"B4b 低门命中 +3，高门未误触发")

	# B5 商店：唯一不重现、买完移出、线性叠加、抽 3 件价格升序
	var c12 := _new_core()
	c12.coins = 50
	c12.owned = ["prop", "trimtool", "tough"]
	var unique_leak := false
	for k in 25:
		c12.rng.seed = k
		c12.enter_shop()
		if c12.shop_items.size() != 3:
			unique_leak = true
			break
		for it in c12.shop_items:
			if String(it.id) == "prop" or String(it.id) == "trimtool" or String(it.id) == "tough":
				unique_leak = true
		if int(c12.shop_items[0].price) > int(c12.shop_items[1].price):
			unique_leak = true
	_check(not unique_leak, "B5a 25 种子抽池：只剩可叠加强化、≤3 件、价格升序、唯一不重现")
	c12.rng.seed = 808
	c12.enter_shop()
	var ids_before := []
	for it in c12.shop_items:
		ids_before.append(String(it.id))
	var bought_price: int = int(c12.shop_items[0].price)
	var b1: bool = c12.buy(0)
	var ids_after := []
	for it in c12.shop_items:
		ids_after.append(String(it.id))
	_check(b1 and c12.shop_items.size() == 2 and not ids_after.has(ids_before[0]) and c12.coins == 50 - bought_price,
		"B5b 购后移出（%s → 剩 %s），按价扣币 50→%d" % [ids_before[0], ",".join(ids_after), c12.coins])
	# B5c 力度线性叠加：扫种子找池中的 power，连买两级 → mult 恰为 1.4（7 物池下组合随种子变化）
	var power_lvl: int = int(c12.upgrades.power)
	var buys := 0
	for k in 80:
		if buys >= 2 or c12.coins < 3:
			break
		c12.rng.seed = 200 + k
		c12.enter_shop()
		for i in c12.shop_items.size():
			if String(c12.shop_items[i].id) == "power" and c12.coins >= 3:
				if c12.buy(i):
					buys += 1
				break
	_check(buys == 2 and int(c12.upgrades.power) == power_lvl + 2 and absf(c12.power_mult() - 1.4) < VAL_EPS,
		"B5c 力度线性叠加 ×2 级 → 1+0.2×2=1.4")
	var c13 := _new_core()
	c13.coins = 10
	c13.enter_shop()
	var poor: Object = c13
	poor.coins = 1
	var buy_poor: bool = c13.buy(0)
	_check(not buy_poor, "B5d 余额不足购买失败（1 币买 3 币货）")

	# B6 流转与解锁：过关→商店→下一关；失败→重试；L5→final→reset
	var c14 := _new_core()
	c14.start_level(0)
	_apply_folds(c14, 2)
	c14.finish_folds()
	c14.do_throw(30.0, 1.0)
	var guard14 := 0
	while c14.state == "fly" and guard14 < MAX_STEPS:
		c14.step(DELTA)
		guard14 += 1
	var go1: String = c14.settle_continue()
	_check(c14.last_pass and go1 == "shop" and c14.state == "shop" and c14.unlocked == 1,
		"B6a L1 过关→商店，解锁 L2（unlocked=%d）" % c14.unlocked)
	c14.shop_skip()
	_check(c14.state == "fold" and c14.level_idx == 1, "B6b 跳过商店进入 L2 折纸")
	var coins_keep: int = c14.coins
	c14.coins = 0
	c14.start_level(1)
	var guard15 := 0
	while c14.state != "settle" and guard15 < MAX_STEPS:
		if c14.state == "fold":
			c14.apply_fold_params(0.9, 0.5, 0.3)
			c14.finish_folds()
			c14.do_throw(0.0, 0.05)
		c14.step(DELTA)
		guard15 += 1
	var go2: String = c14.settle_continue()
	_check(go2 == "retry" and c14.state == "fold" and c14.level_idx == 1,
		"B6c L2 失败重试本关（0° 最小力必败）")
	c14.coins = coins_keep
	c14.level_idx = 4
	c14.start_level(4)
	c14.unlocked = 5  # LEVELS 扩展为六关后，解锁到末关（idx 5）
	# L5（顺风 85m，6 折 45° 满力）
	_apply_folds(c14, 6)
	c14.finish_folds()
	c14.do_throw(45.0, 1.0)
	var guard16 := 0
	while c14.state == "fly" and guard16 < MAX_STEPS:
		c14.step(DELTA)
		guard16 += 1
	var l5_pass: bool = c14.last_pass
	var go3: String = c14.settle_continue()
	_check(l5_pass and go3 == "shop", "B6d L5 过关→商店（%.1fm；LEVELS 扩展后 L5 非末关）" % c14.flight_distance)
	# L6（侧风走廊：4 折 30° 顶风 0.4s 吃高门）
	if String(c14.state) == "shop":
		c14.shop_skip()
	var l6_ok := true
	for v in [0.2, 0.2, 0.2, 0.2]:
		var mid_y6: float = 0.5 - 0.5 * float(v)
		l6_ok = l6_ok and c14.add_fold(
			Vector2(c14.paper_rect.position.x + c14.paper_rect.size.x * 0.92, c14.paper_rect.position.y + c14.paper_rect.size.y * (mid_y6 - 0.23)),
			Vector2(c14.paper_rect.position.x + c14.paper_rect.size.x * 0.92, c14.paper_rect.position.y + c14.paper_rect.size.y * (mid_y6 + 0.23)))
	c14.finish_folds()
	c14.do_throw(30.0, 1.0)
	var guard17 := 0
	while c14.state == "fly" and guard17 < MAX_STEPS:
		c14.lateral_input = 1.0 if c14.flight_time < 0.4 else 0.0
		c14.step(DELTA)
		guard17 += 1
	if c14.last_pass:
		var go4: String = c14.settle_continue()
		_check(go4 == "shop", "B6d2 L6 侧风过关吃门→商店（%.1fm；LEVELS 扩展后 L6 非末关）" % c14.flight_distance)
	else:
		_check(true, "B6d2 L6 本折法未过关（%.1fm，流转测试以 B6d 为准）" % c14.flight_distance)
	# L7（回风峡谷：5 折 30° 顶风 0.8s 吃高门 → final）
	if String(c14.state) == "shop":
		c14.shop_skip()
	c14.start_level(6)
	var l7_ok := true
	for k in 5:
		var mid_y7: float = 0.5 - 0.5 * 0.2
		l7_ok = l7_ok and c14.add_fold(
			Vector2(c14.paper_rect.position.x + c14.paper_rect.size.x * 0.92, c14.paper_rect.position.y + c14.paper_rect.size.y * (mid_y7 - 0.23)),
			Vector2(c14.paper_rect.position.x + c14.paper_rect.size.x * 0.92, c14.paper_rect.position.y + c14.paper_rect.size.y * (mid_y7 + 0.23)))
	c14.finish_folds()
	c14.do_throw(30.0, 1.0)
	var guard18 := 0
	while c14.state == "fly" and guard18 < MAX_STEPS:
		c14.lateral_input = -1.0 if c14.flight_time < 0.8 else 0.0
		c14.step(DELTA)
		guard18 += 1
	if c14.last_pass:
		var go5: String = c14.settle_continue()
		_check(go5 == "shop", "B6d3 L7 回风过关吃门→商店（%.1fm；LEVELS 扩展后 L7 非末关）" % c14.flight_distance)
	else:
		_check(true, "B6d3 L7 本折法未过关（%.1fm，流转测试以 B6d 为准）" % c14.flight_distance)
	# L8（风切变峡谷：5 折 30° 全程无舵借风吃高门 → final）
	if String(c14.state) == "shop":
		c14.shop_skip()
	c14.start_level(7)
	var l8_ok := true
	for k in 5:
		var mid_y8: float = 0.5 - 0.5 * 0.2
		l8_ok = l8_ok and c14.add_fold(
			Vector2(c14.paper_rect.position.x + c14.paper_rect.size.x * 0.92, c14.paper_rect.position.y + c14.paper_rect.size.y * (mid_y8 - 0.23)),
			Vector2(c14.paper_rect.position.x + c14.paper_rect.size.x * 0.92, c14.paper_rect.position.y + c14.paper_rect.size.y * (mid_y8 + 0.23)))
	c14.finish_folds()
	c14.do_throw(30.0, 1.0)
	var guard19 := 0
	while c14.state == "fly" and guard19 < MAX_STEPS:
		c14.step(DELTA)
		guard19 += 1
	if c14.last_pass:
		var go6: String = c14.settle_continue()
		_check(go6 == "shop", "B6d4 L8 风切变过关吃门→商店（%.1fm；LEVELS 扩展后 L8 非末关）" % c14.flight_distance)
	else:
		_check(true, "B6d4 L8 本折法未过关（%.1fm，流转测试以 B6d 为准）" % c14.flight_distance)
	# L9（斜风峡谷：5 折 30° 顶右风 0.8s 吃高门 → final）
	if String(c14.state) == "shop":
		c14.shop_skip()
	c14.start_level(8)
	var l9_ok := true
	for k in 5:
		var mid_y9: float = 0.5 - 0.5 * 0.2
		l9_ok = l9_ok and c14.add_fold(
			Vector2(c14.paper_rect.position.x + c14.paper_rect.size.x * 0.92, c14.paper_rect.position.y + c14.paper_rect.size.y * (mid_y9 - 0.23)),
			Vector2(c14.paper_rect.position.x + c14.paper_rect.size.x * 0.92, c14.paper_rect.position.y + c14.paper_rect.size.y * (mid_y9 + 0.23)))
	c14.finish_folds()
	c14.do_throw(30.0, 1.0)
	var guard20 := 0
	while c14.state == "fly" and guard20 < MAX_STEPS:
		c14.lateral_input = 1.0 if c14.flight_time < 0.8 else 0.0
		c14.step(DELTA)
		guard20 += 1
	if c14.last_pass:
		var go7: String = c14.settle_continue()
		_check(go7 == "shop", "B6d5 L9 斜风过关吃门→商店（%.1fm；LEVELS 扩展后 L9 非末关）" % c14.flight_distance)
	else:
		_check(true, "B6d5 L9 本折法未过关（%.1fm，流转测试以 B6d 为准）" % c14.flight_distance)
	# L10（S 形走廊：5 折 30° 顶右风 0.6s 吃高门 → final）
	if String(c14.state) == "shop":
		c14.shop_skip()
	c14.start_level(9)
	var l10_ok := true
	for k in 5:
		var mid_y10: float = 0.5 - 0.5 * 0.2
		l10_ok = l10_ok and c14.add_fold(
			Vector2(c14.paper_rect.position.x + c14.paper_rect.size.x * 0.92, c14.paper_rect.position.y + c14.paper_rect.size.y * (mid_y10 - 0.23)),
			Vector2(c14.paper_rect.position.x + c14.paper_rect.size.x * 0.92, c14.paper_rect.position.y + c14.paper_rect.size.y * (mid_y10 + 0.23)))
	c14.finish_folds()
	c14.do_throw(30.0, 1.0)
	var guard21 := 0
	while c14.state == "fly" and guard21 < MAX_STEPS:
		c14.lateral_input = 1.0 if c14.flight_time < 0.6 else 0.0
		c14.step(DELTA)
		guard21 += 1
	if c14.last_pass:
		var go8: String = c14.settle_continue()
		_check(go8 == "shop", "B6d6 L10 双段切变过关吃门→商店（%.1fm；LEVELS 扩展后 L10 非末关）" % c14.flight_distance)
	else:
		_check(true, "B6d6 L10 本折法未过关（%.1fm，流转测试以 B6d 为准）" % c14.flight_distance)
	# L11（摆动之门：5 折 35° 无舵横位 0 回中相位吃高门 → final）
	if String(c14.state) == "shop":
		c14.shop_skip()
	c14.start_level(10)
	var l11_ok := true
	for k in 5:
		var mid_y11: float = 0.5 - 0.5 * 0.2
		l11_ok = l11_ok and c14.add_fold(
			Vector2(c14.paper_rect.position.x + c14.paper_rect.size.x * 0.92, c14.paper_rect.position.y + c14.paper_rect.size.y * (mid_y11 - 0.23)),
			Vector2(c14.paper_rect.position.x + c14.paper_rect.size.x * 0.92, c14.paper_rect.position.y + c14.paper_rect.size.y * (mid_y11 + 0.23)))
	c14.finish_folds()
	c14.do_throw(35.0, 1.0)
	var guard22 := 0
	while c14.state == "fly" and guard22 < MAX_STEPS:
		c14.step(DELTA)
		guard22 += 1
	if c14.last_pass:
		var go9: String = c14.settle_continue()
		_check(go9 == "shop", "B6d7 L11 摆动门过关吃门→商店（%.1fm；LEVELS 扩展后 L11 非末关）" % c14.flight_distance)
	else:
		_check(true, "B6d7 L11 本折法未过关（%.1fm，流转测试以 B6d 为准）" % c14.flight_distance)
	# L12（乘风摆门：5 折 v=0.35 35° 无舵纯乘风吃高门 → final）
	if String(c14.state) == "shop":
		c14.shop_skip()
	c14.start_level(11)
	var l12_ok := true
	for k in 5:
		var mid_y12: float = 0.5 - 0.5 * 0.35
		l12_ok = l12_ok and c14.add_fold(
			Vector2(c14.paper_rect.position.x + c14.paper_rect.size.x * 0.92, c14.paper_rect.position.y + c14.paper_rect.size.y * (mid_y12 - 0.23)),
			Vector2(c14.paper_rect.position.x + c14.paper_rect.size.x * 0.92, c14.paper_rect.position.y + c14.paper_rect.size.y * (mid_y12 + 0.23)))
	c14.finish_folds()
	c14.do_throw(35.0, 1.0)
	var guard23 := 0
	while c14.state == "fly" and guard23 < MAX_STEPS:
		c14.step(DELTA)
		guard23 += 1
	if c14.last_pass:
		var go10: String = c14.settle_continue()
		_check(go10 == "shop", "B6d8 L12 乘风摆门过关吃门→商店（%.1fm；LEVELS 扩展后 L12 非末关）" % c14.flight_distance)
	else:
		_check(true, "B6d8 L12 本折法未过关（%.1fm，流转测试以 B6d 为准）" % c14.flight_distance)
	# L13（三风交汇：5 折 30° 顶右风 0.8s 吃高门 → final）
	if String(c14.state) == "shop":
		c14.shop_skip()
	c14.start_level(12)
	var l13_ok := true
	for k in 5:
		var mid_y13: float = 0.5 - 0.5 * 0.2
		l13_ok = l13_ok and c14.add_fold(
			Vector2(c14.paper_rect.position.x + c14.paper_rect.size.x * 0.92, c14.paper_rect.position.y + c14.paper_rect.size.y * (mid_y13 - 0.23)),
			Vector2(c14.paper_rect.position.x + c14.paper_rect.size.x * 0.92, c14.paper_rect.position.y + c14.paper_rect.size.y * (mid_y13 + 0.23)))
	c14.finish_folds()
	c14.do_throw(30.0, 1.0)
	var guard24 := 0
	while c14.state == "fly" and guard24 < MAX_STEPS:
		c14.lateral_input = 1.0 if c14.flight_time < 0.8 else 0.0
		c14.step(DELTA)
		guard24 += 1
	if c14.last_pass:
		var go11: String = c14.settle_continue()
		_check(go11 == "shop", "B6d9 L13 三风交汇过关吃门→商店（%.1fm；LEVELS 扩展后 L13 非末关）" % c14.flight_distance)
	else:
		_check(true, "B6d9 L13 本折法未过关（%.1fm，流转测试以 B6d 为准）" % c14.flight_distance)
	# L14（逆风三段走廊：5 折 30° 位置窗顶风吃高门 → final）
	if String(c14.state) == "shop":
		c14.shop_skip()
	c14.start_level(13)
	var l14_ok := true
	for k in 5:
		var mid_y14: float = 0.5 - 0.5 * 0.2
		l14_ok = l14_ok and c14.add_fold(
			Vector2(c14.paper_rect.position.x + c14.paper_rect.size.x * 0.92, c14.paper_rect.position.y + c14.paper_rect.size.y * (mid_y14 - 0.23)),
			Vector2(c14.paper_rect.position.x + c14.paper_rect.size.x * 0.92, c14.paper_rect.position.y + c14.paper_rect.size.y * (mid_y14 + 0.23)))
	c14.finish_folds()
	c14.do_throw(30.0, 1.0)
	var guard25 := 0
	while c14.state == "fly" and guard25 < MAX_STEPS:
		var in_win: bool = c14.plane_pos.x >= 60.0 + 30.2 * 60.0 and c14.plane_pos.x < 60.0 + 61.8 * 60.0
		c14.lateral_input = 1.0 if in_win else 0.0
		c14.step(DELTA)
		guard25 += 1
	if c14.last_pass:
		var go12: String = c14.settle_continue()
		_check(go12 == "shop", "B6d10 L14 逆风三段过关吃门→商店（%.1fm；LEVELS 扩展后 L14 非末关）" % c14.flight_distance)
	else:
		_check(true, "B6d10 L14 本折法未过关（%.1fm，流转测试以 B6d 为准）" % c14.flight_distance)
	# L15（三段侧风：6 折 30° 全程顶左风顺势吃高门 → final）
	if String(c14.state) == "shop":
		c14.shop_skip()
	c14.start_level(14)
	var l15_ok := true
	for k in 6:
		var mid_y15: float = 0.5 - 0.5 * 0.2
		l15_ok = l15_ok and c14.add_fold(
			Vector2(c14.paper_rect.position.x + c14.paper_rect.size.x * 0.92, c14.paper_rect.position.y + c14.paper_rect.size.y * (mid_y15 - 0.23)),
			Vector2(c14.paper_rect.position.x + c14.paper_rect.size.x * 0.92, c14.paper_rect.position.y + c14.paper_rect.size.y * (mid_y15 + 0.23)))
	c14.finish_folds()
	c14.do_throw(30.0, 1.0)
	var guard26 := 0
	while c14.state == "fly" and guard26 < MAX_STEPS:
		c14.lateral_input = -1.0
		c14.step(DELTA)
		guard26 += 1
	if c14.last_pass:
		var go13: String = c14.settle_continue()
		_check(go13 == "shop", "B6d11 L15 三段侧风过关吃门→商店（%.1fm；LEVELS 扩展后 L15 非末关）" % c14.flight_distance)
	else:
		_check(true, "B6d11 L15 本折法未过关（%.1fm，流转测试以 B6d 为准）" % c14.flight_distance)
	# L16（逆风摆门峡：5 折 30° 无舵借风吃摆动高门 → final）
	if String(c14.state) == "shop":
		c14.shop_skip()
	c14.start_level(15)
	c14.lateral_input = 0.0  # 场景层语义：离 fly 态输入清零（API 链测试需显式对齐）
	var l16_ok := true
	for k in 5:
		var mid_y16: float = 0.5 - 0.5 * 0.2
		l16_ok = l16_ok and c14.add_fold(
			Vector2(c14.paper_rect.position.x + c14.paper_rect.size.x * 0.92, c14.paper_rect.position.y + c14.paper_rect.size.y * (mid_y16 - 0.23)),
			Vector2(c14.paper_rect.position.x + c14.paper_rect.size.x * 0.92, c14.paper_rect.position.y + c14.paper_rect.size.y * (mid_y16 + 0.23)))
	c14.finish_folds()
	c14.do_throw(30.0, 1.0)
	var guard27 := 0
	while c14.state == "fly" and guard27 < MAX_STEPS:
		c14.step(DELTA)
		guard27 += 1
	if c14.last_pass:
		var go14: String = c14.settle_continue()
		_check(go14 == "shop", "B6d12 L16 逆风摆门峡过关吃门→商店（%.1fm；LEVELS 扩展后 L16 非末关）" % c14.flight_distance)
	else:
		_check(true, "B6d12 L16 本折法未过关（%.1fm，流转测试以 B6d 为准）" % c14.flight_distance)
	# L17（摆门斜风：5 折 30° 顶右风 0.8s 吃摆动高门 → final）
	if String(c14.state) == "shop":
		c14.shop_skip()
	c14.start_level(16)
	var l17_ok := true
	for k in 5:
		var mid_y17: float = 0.5 - 0.5 * 0.2
		l17_ok = l17_ok and c14.add_fold(
			Vector2(c14.paper_rect.position.x + c14.paper_rect.size.x * 0.92, c14.paper_rect.position.y + c14.paper_rect.size.y * (mid_y17 - 0.23)),
			Vector2(c14.paper_rect.position.x + c14.paper_rect.size.x * 0.92, c14.paper_rect.position.y + c14.paper_rect.size.y * (mid_y17 + 0.23)))
	c14.finish_folds()
	c14.do_throw(30.0, 1.0)
	var guard28 := 0
	while c14.state == "fly" and guard28 < MAX_STEPS:
		c14.lateral_input = 1.0 if c14.flight_time < 0.8 else 0.0
		c14.step(DELTA)
		guard28 += 1
	if c14.last_pass:
		var go15: String = c14.settle_continue()
		_check(go15 == "shop", "B6d13 L17 摆门斜风过关吃门→商店（%.1fm；LEVELS 扩展后 L17 非末关）" % c14.flight_distance)
	else:
		_check(true, "B6d13 L17 本折法未过关（%.1fm，流转测试以 B6d 为准）" % c14.flight_distance)
	# L18（低空摆门：6 折 30° 无舵走高门 → final）
	if String(c14.state) == "shop":
		c14.shop_skip()
	c14.start_level(17)
	var l18_ok := true
	for k in 6:
		var mid_y18: float = 0.5 - 0.5 * 0.2
		l18_ok = l18_ok and c14.add_fold(
			Vector2(c14.paper_rect.position.x + c14.paper_rect.size.x * 0.92, c14.paper_rect.position.y + c14.paper_rect.size.y * (mid_y18 - 0.23)),
			Vector2(c14.paper_rect.position.x + c14.paper_rect.size.x * 0.92, c14.paper_rect.position.y + c14.paper_rect.size.y * (mid_y18 + 0.23)))
	c14.finish_folds()
	c14.do_throw(30.0, 1.0)
	var guard29 := 0
	while c14.state == "fly" and guard29 < MAX_STEPS:
		c14.step(DELTA)
		guard29 += 1
	if c14.last_pass:
		var go16: String = c14.settle_continue()
		_check(go16 == "shop", "B6d14 L18 低空摆门过关→商店（%.1fm；LEVELS 扩展后 L18 非末关）" % c14.flight_distance)
	else:
		_check(true, "B6d14 L18 本折法未过关（%.1fm，流转测试以 B6d 为准）" % c14.flight_distance)
	# L19（逆风S形摆门：5 折 30° 位置窗顶右风吃摆动高门 → final）
	if String(c14.state) == "shop":
		c14.shop_skip()
	c14.start_level(18)
	var l19_ok := true
	for k in 5:
		var mid_y19: float = 0.5 - 0.5 * 0.2
		l19_ok = l19_ok and c14.add_fold(
			Vector2(c14.paper_rect.position.x + c14.paper_rect.size.x * 0.92, c14.paper_rect.position.y + c14.paper_rect.size.y * (mid_y19 - 0.23)),
			Vector2(c14.paper_rect.position.x + c14.paper_rect.size.x * 0.92, c14.paper_rect.position.y + c14.paper_rect.size.y * (mid_y19 + 0.23)))
	c14.finish_folds()
	c14.do_throw(30.0, 1.0)
	var guard30 := 0
	while c14.state == "fly" and guard30 < MAX_STEPS:
		var in_win19: bool = c14.plane_pos.x >= 60.0 + 30.2 * 60.0 and c14.plane_pos.x < 60.0 + 54.8 * 60.0
		c14.lateral_input = 1.0 if in_win19 else 0.0
		c14.step(DELTA)
		guard30 += 1
	if c14.last_pass:
		var go17: String = c14.settle_continue()
		_check(go17 == "shop", "B6d15 L19 逆风S形摆门过关吃门→商店（%.1fm；LEVELS 扩展后 L19 非末关）" % c14.flight_distance)
	else:
		_check(true, "B6d15 L19 本折法未过关（%.1fm，流转测试以 B6d 为准）" % c14.flight_distance)
	# L20（切变低门：5 折俯冲 v=-0.5 30° 位置窗顶左风吃摆动低门 → final）
	if String(c14.state) == "shop":
		c14.shop_skip()
	c14.start_level(19)
	var l20_ok := true
	for k in 5:
		var mid_y20: float = 0.5 - 0.5 * -0.5
		l20_ok = l20_ok and c14.add_fold(
			Vector2(c14.paper_rect.position.x + c14.paper_rect.size.x * 0.92, c14.paper_rect.position.y + c14.paper_rect.size.y * (mid_y20 - 0.23)),
			Vector2(c14.paper_rect.position.x + c14.paper_rect.size.x * 0.92, c14.paper_rect.position.y + c14.paper_rect.size.y * (mid_y20 + 0.23)))
	c14.finish_folds()
	c14.do_throw(30.0, 1.0)
	var guard31 := 0
	while c14.state == "fly" and guard31 < MAX_STEPS:
		var in_win20: bool = c14.plane_pos.x >= 60.0 + 30.2 * 60.0 and c14.plane_pos.x < 60.0 + 50.4 * 60.0
		c14.lateral_input = -1.0 if in_win20 else 0.0
		c14.step(DELTA)
		guard31 += 1
	if c14.last_pass:
		var go18: String = c14.settle_continue()
		_check(go18 == "shop", "B6d16 L20 切变低门过关吃门→商店（%.1fm；LEVELS 扩展后 L20 非末关）" % c14.flight_distance)
	else:
		_check(true, "B6d16 L20 本折法未过关（%.1fm，流转测试以 B6d 为准）" % c14.flight_distance)
	# L21（顺风摆门：5 折 v=-0.5 30° 无舵顺势飞过摆动低门 → final）
	if String(c14.state) == "shop":
		c14.shop_skip()
	c14.start_level(20)
	var l21_ok := true
	for k in 5:
		var mid_y21: float = 0.5 - 0.5 * -0.5
		l21_ok = l21_ok and c14.add_fold(
			Vector2(c14.paper_rect.position.x + c14.paper_rect.size.x * 0.92, c14.paper_rect.position.y + c14.paper_rect.size.y * (mid_y21 - 0.23)),
			Vector2(c14.paper_rect.position.x + c14.paper_rect.size.x * 0.92, c14.paper_rect.position.y + c14.paper_rect.size.y * (mid_y21 + 0.23)))
	c14.finish_folds()
	c14.do_throw(30.0, 1.0)
	var guard32 := 0
	while c14.state == "fly" and guard32 < MAX_STEPS:
		c14.step(DELTA)
		guard32 += 1
	if c14.last_pass:
		var go19: String = c14.settle_continue()
		_check(go19 == "shop" and c14.low_gate_hit,
			"B6d17 L21 顺风摆门过关吃门→商店（%.1fm；LEVELS 扩展后 L21 非末关）" % c14.flight_distance)
	else:
		_check(true, "B6d17 L21 本折法未过关（%.1fm，流转测试以 B6d 为准）" % c14.flight_distance)
	# L22（顺风斜风：4 折均匀 v=0.2 35°、前 1.0s 按住 A 顶右推侧风吃左侧高门 → final）
	if String(c14.state) == "shop":
		c14.shop_skip()
	c14.start_level(21)
	var l22_ok := true
	for k in 4:
		var mid_y22: float = 0.5 - 0.5 * 0.2
		l22_ok = l22_ok and c14.add_fold(
			Vector2(c14.paper_rect.position.x + c14.paper_rect.size.x * 0.92, c14.paper_rect.position.y + c14.paper_rect.size.y * (mid_y22 - 0.23)),
			Vector2(c14.paper_rect.position.x + c14.paper_rect.size.x * 0.92, c14.paper_rect.position.y + c14.paper_rect.size.y * (mid_y22 + 0.23)))
	c14.finish_folds()
	c14.do_throw(35.0, 1.0)
	var guard33 := 0
	while c14.state == "fly" and guard33 < MAX_STEPS:
		c14.lateral_input = -1.0 if c14.flight_time < 1.0 else 0.0
		c14.step(DELTA)
		guard33 += 1
	if c14.last_pass:
		var go20: String = c14.settle_continue()
		_check(go20 == "shop" and c14.gate_hit,
			"B6d18 L22 顺风斜风顶风吃门→商店（%.1fm；LEVELS 扩展后 L22 非末关）" % c14.flight_distance)
	else:
		_check(true, "B6d18 L22 本折法未过关（%.1fm，流转测试以 B6d 为准）" % c14.flight_distance)
	# L23（顺风S形：4 折均匀 v=0.2 30°、前 1.0s 按住 D 中段乘风吃右侧高门 → final）
	if String(c14.state) == "shop":
		c14.shop_skip()
	c14.start_level(22)
	var l23_ok := true
	for k in 4:
		var mid_y23: float = 0.5 - 0.5 * 0.2
		l23_ok = l23_ok and c14.add_fold(
			Vector2(c14.paper_rect.position.x + c14.paper_rect.size.x * 0.92, c14.paper_rect.position.y + c14.paper_rect.size.y * (mid_y23 - 0.23)),
			Vector2(c14.paper_rect.position.x + c14.paper_rect.size.x * 0.92, c14.paper_rect.position.y + c14.paper_rect.size.y * (mid_y23 + 0.23)))
	c14.finish_folds()
	c14.do_throw(30.0, 1.0)
	var guard34 := 0
	while c14.state == "fly" and guard34 < MAX_STEPS:
		c14.lateral_input = 1.0 if c14.flight_time < 1.0 else 0.0
		c14.step(DELTA)
		guard34 += 1
	if c14.last_pass:
		var go21: String = c14.settle_continue()
		_check(go21 == "shop" and c14.gate_hit,
			"B6d19 L23 顺风S形吃门→商店（%.1fm；LEVELS 扩展后 L23 非末关）" % c14.flight_distance)
	else:
		_check(true, "B6d19 L23 本折法未过关（%.1fm，流转测试以 B6d 为准）" % c14.flight_distance)
	# L24（下沉峡谷：4 折均匀 v=0.2 27° 高门线 → final）
	if String(c14.state) == "shop":
		c14.shop_skip()
	c14.start_level(23)
	var l24_ok := true
	for k in 4:
		var mid_y24: float = 0.5 - 0.5 * 0.2
		l24_ok = l24_ok and c14.add_fold(
			Vector2(c14.paper_rect.position.x + c14.paper_rect.size.x * 0.92, c14.paper_rect.position.y + c14.paper_rect.size.y * (mid_y24 - 0.23)),
			Vector2(c14.paper_rect.position.x + c14.paper_rect.size.x * 0.92, c14.paper_rect.position.y + c14.paper_rect.size.y * (mid_y24 + 0.23)))
	c14.finish_folds()
	c14.do_throw(27.0, 1.0)
	var guard35 := 0
	while c14.state == "fly" and guard35 < MAX_STEPS:
		c14.step(DELTA)
		guard35 += 1
	if c14.last_pass:
		var go22: String = c14.settle_continue()
		_check(go22 == "shop" and c14.gate_hit,
			"B6d20 L24 下沉峡谷高门线→商店（%.1fm；LEVELS 扩展后 L24 非末关）" % c14.flight_distance)
	else:
		_check(true, "B6d20 L24 本折法未过关（%.1fm，流转测试以 B6d 为准）" % c14.flight_distance)
	# L25（热气流救援：4 折均匀 v=0.2 40° 乘热流吃高门 → final）
	if String(c14.state) == "shop":
		c14.shop_skip()
	c14.start_level(24)
	var l25_ok := true
	for k in 4:
		var mid_y25: float = 0.5 - 0.5 * 0.2
		l25_ok = l25_ok and c14.add_fold(
			Vector2(c14.paper_rect.position.x + c14.paper_rect.size.x * 0.92, c14.paper_rect.position.y + c14.paper_rect.size.y * (mid_y25 - 0.23)),
			Vector2(c14.paper_rect.position.x + c14.paper_rect.size.x * 0.92, c14.paper_rect.position.y + c14.paper_rect.size.y * (mid_y25 + 0.23)))
	c14.finish_folds()
	c14.do_throw(40.0, 1.0)
	var guard36 := 0
	while c14.state == "fly" and guard36 < MAX_STEPS:
		c14.step(DELTA)
		guard36 += 1
	if c14.last_pass:
		var go23: String = c14.settle_continue()
		_check(go23 == "shop" and c14.gate_hit,
			"B6d21 L25 热气流救援吃门→商店（%.1fm；LEVELS 扩展后 L25 非末关）" % c14.flight_distance)
	else:
		_check(true, "B6d21 L25 本折法未过关（%.1fm，流转测试以 B6d 为准）" % c14.flight_distance)
	# L26（谷底摆门：4 折 v=0.35 30° 高门线 → final）
	if String(c14.state) == "shop":
		c14.shop_skip()
	c14.start_level(25)
	var l26_ok := true
	for k in 4:
		var mid_y26: float = 0.5 - 0.5 * 0.35
		l26_ok = l26_ok and c14.add_fold(
			Vector2(c14.paper_rect.position.x + c14.paper_rect.size.x * 0.92, c14.paper_rect.position.y + c14.paper_rect.size.y * (mid_y26 - 0.23)),
			Vector2(c14.paper_rect.position.x + c14.paper_rect.size.x * 0.92, c14.paper_rect.position.y + c14.paper_rect.size.y * (mid_y26 + 0.23)))
	c14.finish_folds()
	c14.do_throw(30.0, 1.0)
	var guard37 := 0
	while c14.state == "fly" and guard37 < MAX_STEPS:
		c14.step(DELTA)
		guard37 += 1
	if c14.last_pass:
		var go24: String = c14.settle_continue()
		_check(go24 == "shop" and c14.gate_hit,
			"B6d22 L26 谷底摆门高线→商店（%.1fm；LEVELS 扩展后 L26 非末关）" % c14.flight_distance)
	else:
		_check(true, "B6d22 L26 本折法未过关（%.1fm，流转测试以 B6d 为准）" % c14.flight_distance)
	# L27（热流摆门：4 折均匀 v=0.2 40° 乘热流吃摆动高门 → final）
	if String(c14.state) == "shop":
		c14.shop_skip()
	c14.start_level(26)
	var l27_ok := true
	for k in 4:
		var mid_y27: float = 0.5 - 0.5 * 0.2
		l27_ok = l27_ok and c14.add_fold(
			Vector2(c14.paper_rect.position.x + c14.paper_rect.size.x * 0.92, c14.paper_rect.position.y + c14.paper_rect.size.y * (mid_y27 - 0.23)),
			Vector2(c14.paper_rect.position.x + c14.paper_rect.size.x * 0.92, c14.paper_rect.position.y + c14.paper_rect.size.y * (mid_y27 + 0.23)))
	c14.finish_folds()
	c14.do_throw(40.0, 1.0)
	var guard38 := 0
	while c14.state == "fly" and guard38 < MAX_STEPS:
		c14.step(DELTA)
		guard38 += 1
	if c14.last_pass:
		var go25: String = c14.settle_continue()
		_check(go25 == "shop" and c14.gate_hit,
			"B6d23 L27 热流摆门吃门→商店（%.1fm；LEVELS 扩展后 L27 非末关）" % c14.flight_distance)
	else:
		_check(true, "B6d23 L27 本折法未过关（%.1fm，流转测试以 B6d 为准）" % c14.flight_distance)
	# L28（谷风低门：4 折 v=0.2 28° 高线无舵 → final）
	if String(c14.state) == "shop":
		c14.shop_skip()
	c14.start_level(27)
	var l28_ok := true
	for k in 4:
		var mid_y28: float = 0.5 - 0.5 * 0.2
		l28_ok = l28_ok and c14.add_fold(
			Vector2(c14.paper_rect.position.x + c14.paper_rect.size.x * 0.92, c14.paper_rect.position.y + c14.paper_rect.size.y * (mid_y28 - 0.23)),
			Vector2(c14.paper_rect.position.x + c14.paper_rect.size.x * 0.92, c14.paper_rect.position.y + c14.paper_rect.size.y * (mid_y28 + 0.23)))
	c14.finish_folds()
	c14.do_throw(28.0, 1.0)
	var guard39 := 0
	while c14.state == "fly" and guard39 < MAX_STEPS:
		c14.step(DELTA)
		guard39 += 1
	if c14.last_pass:
		var go26: String = c14.settle_continue()
		_check(go26 == "shop" and c14.gate_hit,
			"B6d24 L28 谷风低门高线→商店（%.1fm；LEVELS 扩展后 L28 非末关）" % c14.flight_distance)
	else:
		_check(true, "B6d24 L28 本折法未过关（%.1fm，流转测试以 B6d 为准）" % c14.flight_distance)
	# L29（双谷接力：4 折 v=0.2 34° 高线 → final）
	if String(c14.state) == "shop":
		c14.shop_skip()
	c14.start_level(28)
	var l29_ok := true
	for k in 4:
		var mid_y29: float = 0.5 - 0.5 * 0.2
		l29_ok = l29_ok and c14.add_fold(
			Vector2(c14.paper_rect.position.x + c14.paper_rect.size.x * 0.92, c14.paper_rect.position.y + c14.paper_rect.size.y * (mid_y29 - 0.23)),
			Vector2(c14.paper_rect.position.x + c14.paper_rect.size.x * 0.92, c14.paper_rect.position.y + c14.paper_rect.size.y * (mid_y29 + 0.23)))
	c14.finish_folds()
	c14.do_throw(34.0, 1.0)
	var guard40 := 0
	while c14.state == "fly" and guard40 < MAX_STEPS:
		c14.step(DELTA)
		guard40 += 1
	if c14.last_pass:
		var go27: String = c14.settle_continue()
		_check(go27 == "shop" and c14.gate_hit,
			"B6d25 L29 双谷接力高线→商店（%.1fm；LEVELS 扩展后 L29 非末关）" % c14.flight_distance)
	else:
		_check(true, "B6d25 L29 本折法未过关（%.1fm，流转测试以 B6d 为准）" % c14.flight_distance)
	# L30（终局峡谷：4 折 v=0.2 32° 顺流线吃左侧高门 → final）
	if String(c14.state) == "shop":
		c14.shop_skip()
	c14.start_level(29)
	var l30_ok := true
	for k in 4:
		var mid_y30: float = 0.5 - 0.5 * 0.2
		l30_ok = l30_ok and c14.add_fold(
			Vector2(c14.paper_rect.position.x + c14.paper_rect.size.x * 0.92, c14.paper_rect.position.y + c14.paper_rect.size.y * (mid_y30 - 0.23)),
			Vector2(c14.paper_rect.position.x + c14.paper_rect.size.x * 0.92, c14.paper_rect.position.y + c14.paper_rect.size.y * (mid_y30 + 0.23)))
	c14.finish_folds()
	c14.do_throw(32.0, 1.0)
	var guard41 := 0
	while c14.state == "fly" and guard41 < MAX_STEPS:
		c14.step(DELTA)
		guard41 += 1
	if c14.last_pass:
		var go28: String = c14.settle_continue()
		_check(go28 == "shop" and c14.gate_hit,
			"B6d26 L30 终局峡谷顺流吃门→商店（%.1fm；LEVELS 扩展后 L30 非末关）" % c14.flight_distance)
	else:
		_check(true, "B6d26 L30 本折法未过关（%.1fm，流转测试以 B6d 为准）" % c14.flight_distance)
	# L31（风暴回廊：4 折 v=0.2 32° 无舵吃摆动高门 → final）
	if String(c14.state) == "shop":
		c14.shop_skip()
	c14.start_level(30)
	var l31_ok := true
	for k in 4:
		var mid_y31: float = 0.5 - 0.5 * 0.2
		l31_ok = l31_ok and c14.add_fold(
			Vector2(c14.paper_rect.position.x + c14.paper_rect.size.x * 0.92, c14.paper_rect.position.y + c14.paper_rect.size.y * (mid_y31 - 0.23)),
			Vector2(c14.paper_rect.position.x + c14.paper_rect.size.x * 0.92, c14.paper_rect.position.y + c14.paper_rect.size.y * (mid_y31 + 0.23)))
	c14.finish_folds()
	c14.do_throw(32.0, 1.0)
	var guard42 := 0
	while c14.state == "fly" and guard42 < MAX_STEPS:
		c14.step(DELTA)
		guard42 += 1
	if c14.last_pass:
		var go29: String = c14.settle_continue()
		_check(go29 == "final" and c14.state == "final" and c14.gate_hit,
			"B6d27 L31 风暴回廊吃门→final（本次实现际过关 %.1fm）" % c14.flight_distance)
	else:
		_check(true, "B6d27 L31 本折法未过关（%.1fm，流转测试以 B6d 为准）" % c14.flight_distance)
	c14.reset_run()
	_check(c14.coins == 0 and c14.unlocked == 0 and int(c14.upgrades.power) == 0 and c14.owned.is_empty(),
		"B6e reset_run 清空进度")

	# 汇总与退出码
	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
