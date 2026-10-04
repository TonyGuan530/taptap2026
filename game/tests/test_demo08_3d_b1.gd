extends SceneTree
## demo-08 3D 阶段 B1 核心不变量（headless，固定 delta=1/60）：
## 规则变化 B1：A/D 有限侧向转向（升力不耦合/侧向独立阻尼/上限公开/边界±20m）、门横向有效半宽 5m。
## 关键不变量：无输入行为与阶段 A 逐位一致；转向不改变前进/高度轨迹与里程；门出横界不命中。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_b1.gd（失败退出码非零）

const CoreScript := preload("res://demo08_3d/flight_core.gd")
const DELTA := 1.0 / 60.0
const MAX_STEPS := 1500

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


func _make(recipe: String) -> Object:
	var c: Object = CoreScript.new()
	if recipe == "L1":
		c.start_level(0)
		var pr: Rect2 = c.paper_rect
		for k in 2:
			c.add_fold(pr.position + pr.size * Vector2(0.92, 0.08 + 0.06 * float(k)),
				pr.position + pr.size * Vector2(0.92, 0.54 + 0.06 * float(k)))
		c.finish_folds()
		c.do_throw(30.0, 1.0)
	elif recipe == "L2high":
		c.start_level(1)
		var pr2: Rect2 = c.paper_rect
		for k in 4:
			c.add_fold(pr2.position + pr2.size * Vector2(0.92, 0.08 + 0.06 * float(k)),
				pr2.position + pr2.size * Vector2(0.92, 0.54 + 0.06 * float(k)))
		c.finish_folds()
		c.do_throw(42.0, 1.0)
	return c


func _fly(c: Object, input: float) -> Array:
	var pts: Array = []
	var g := 0
	c.lateral_input = input
	while String(c.state) == "fly" and g < MAX_STEPS:
		c.step(DELTA)
		pts.append(c.plane_pos)
		g += 1
	return pts


func _run() -> void:
	await process_frame
	_log("demo-08 3D 阶段 B1 核心不变量测试开始")

	# C1 无输入基线：L2 高门配方结果与阶段 A 一致（横向恒 0）
	var c1 := _make("L2high")
	var lat_max := 0.0
	var g1 := 0
	while String(c1.state) == "fly" and g1 < MAX_STEPS:
		c1.step(DELTA)
		lat_max = maxf(lat_max, absf(float(c1.lateral)))
		g1 += 1
	_check(lat_max < 1e-12 and absf(float(c1.lateral)) < 1e-12, "C1a 无输入横向恒 0")
	_check(c1.gate_hit and not c1.low_gate_hit and c1.coins == 13 and c1.last_pass,
		"C1b L2 无输入结果同阶段 A（高门+3，币 13，%.1fm 过关）" % float(c1.flight_distance))

	# C2 转向不碰前进/高度轨迹：同配方横移满舵 vs 无输入，(x,y) 逐位一致、距离/币一致
	var a := _make("L1")
	var pa := _fly(a, 0.0)
	var b := _make("L1")
	var pb := _fly(b, 1.0)
	var same := pa.size() == pb.size()
	if same:
		for i in pa.size():
			var va: Vector2 = pa[i]
			var vb: Vector2 = pb[i]
			if va.distance_to(vb) > 1e-9:
				same = false
				break
	_check(same, "C2a 满舵横移不改变前进/高度轨迹（%d 步逐位一致）" % pa.size())
	_check(absf(float(a.flight_distance) - float(b.flight_distance)) < 1e-9 and a.coins == b.coins and a.last_pass == b.last_pass,
		"C2b 转向不刷里程/币（距离均 %.2fm）" % float(b.flight_distance))
	_check(float(b.lateral) > 300.0 and absf(float(b.lateral_vel) - float(b.LAT_VMAX)) < 1e-6,
		"C2c 满舵横移 %.0f px，速度达上限 %.0f" % [float(b.lateral), float(b.LAT_VMAX)])

	# C3 松开衰减：单步阻尼衰减量 = LAT_DAMP*delta；飞行期间单调不增
	var c3 := _make("L1")
	c3.lateral_vel = 320.0
	c3.lateral_input = 0.0
	c3.step(DELTA)
	_check(absf(float(c3.lateral_vel) - (320.0 - float(c3.LAT_DAMP) * DELTA)) < 1e-9,
		"C3a 单步阻尼衰减 = LAT_DAMP*delta（%.3f→%.3f）" % [320.0, float(c3.lateral_vel)])
	var prev_v: float = absf(float(c3.lateral_vel))
	var mono := true
	var g4 := 0
	while String(c3.state) == "fly" and g4 < 140:
		c3.step(DELTA)
		var v: float = absf(float(c3.lateral_vel))
		if v > prev_v + 1e-9:
			mono = false
		prev_v = v
		g4 += 1
	_check(mono, "C3b 飞行期间横向速度单调不增")

	# C4 速度上限全程成立（满舵采样）
	var c4 := _make("L1")
	var vmax_ok := true
	var g5 := 0
	c4.lateral_input = 1.0
	while String(c4.state) == "fly" and g5 < MAX_STEPS:
		c4.step(DELTA)
		if absf(float(c4.lateral_vel)) > float(c4.LAT_VMAX) + 1e-9:
			vmax_ok = false
		g5 += 1
	_check(vmax_ok, "C4 横向速度全程 ≤ 上限 %.0f px/s" % float(c4.LAT_VMAX))

	# C5 边界：一步跨过 ±20m → clamp 到界、速度清零、前进继续
	var c5 := _make("L1")
	c5.lateral = 1199.0
	c5.lateral_vel = 320.0
	c5.lateral_input = 1.0
	var xb: float = c5.plane_pos.x
	c5.step(DELTA)
	var xa: float = c5.plane_pos.x
	_check(absf(float(c5.lateral) - float(c5.LAT_LIMIT_PX)) < 1e-6 and absf(float(c5.lateral_vel)) < 1e-9,
		"C5a 横向一步 clamp 到 %.0f px（=±20m）且速度清零" % float(c5.lateral))
	_check(xa > xb + 10.0, "C5b 贴边后前进继续（%.0f→%.0f）" % [xb, xa])

	# C6 门横向语义：横移出 5m 界穿越不算门；界内命中
	var c6 := _make("L2high")
	c6.plane_pos = Vector2(2090.0, -300.0)
	c6.velocity = Vector2(600.0, 0.0)
	c6.lateral = 400.0  # 6.67m > 5m 半宽
	c6.flight_time = 0.0
	for k in 6:
		var e6: String = c6.step(DELTA)
		if e6 == "finish" or e6 == "ground" or e6 == "timeout":
			break
		if c6.plane_pos.x >= 2101.0:
			break
	_check(not c6.gate_hit and c6.coins == 0, "C6a 横移 6.7m 出界 → 高门不命中（币 0）")
	var c7 := _make("L2high")
	c7.plane_pos = Vector2(2090.0, -300.0)
	c7.velocity = Vector2(600.0, 0.0)
	c7.lateral = 100.0  # 1.67m 界内
	c7.flight_time = 0.0
	for k in 6:
		var e7: String = c7.step(DELTA)
		if e7 == "finish" or e7 == "ground" or e7 == "timeout":
			break
		if c7.plane_pos.x >= 2101.0:
			break
	_check(c7.gate_hit and c7.gate_coins == 3, "C6b 横移 1.7m 界内 → 高门命中 +3")

	# C7 偏航符号关系（表现层约定）：右横移 → yaw 为负（机头指向前右）
	_check(float(c7.yaw_rad()) == 0.0 or signf(float(c7.yaw_rad())) != signf(float(c7.lateral_vel)) or c7.lateral_vel == 0.0,
		"C7 yaw 与横移速度符号相反（表现约定）")

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_b1_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
