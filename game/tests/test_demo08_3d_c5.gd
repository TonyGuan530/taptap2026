extends SceneTree
## demo-08 3D 阶段 C5（阶梯②风切变·L8）核心不变量（headless，固定 delta=1/60）：
## 规则变化 C5：LEVELS 可选 shear_x（米，切变平面）/wind_side2（切变后侧风方向）；
## 越过平面后恒定侧风方向翻转（eff_wind_side），L1-L7 无该字段路径逐位不变。
## L8"银行式弹墙"：前段左风带离 → 40m 切变 → 后段右风送回 -3m 高空门（48m）。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c5.gd（失败退出码非零）

const CoreScript := preload("res://demo08_3d/flight_core.gd")
const DELTA := 1.0 / 60.0
const MAX_STEPS := 1800

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


func _mk_l8(folds_n: int, angle: float) -> Object:
	var c: Object = CoreScript.new()
	c.start_level(7)
	if folds_n > 0:
		var pr: Rect2 = c.paper_rect
		for k in folds_n:
			var mid_y: float = 0.5 - 0.5 * 0.2
			c.add_fold(pr.position + pr.size * Vector2(0.92, mid_y - 0.23),
				pr.position + pr.size * Vector2(0.92, mid_y + 0.23))
	c.finish_folds()
	c.do_throw(angle, 1.0)
	var g := 0
	while String(c.state) == "fly" and g < MAX_STEPS:
		c.step(DELTA)
		g += 1
	return c


func _run() -> void:
	await process_frame
	_log("demo-08 3D 阶段 C5 风切变峡谷测试开始")

	# C5-1 切变位置确定：eff_wind_side 在 40m 前后翻转（同状态函数，位置决定）
	var c1: Object = CoreScript.new()
	c1.start_level(7)
	c1.plane_pos.x = 60.0 + 39.0 * 60.0
	var before: float = float(c1.eff_wind_side())
	c1.plane_pos.x = 60.0 + 41.0 * 60.0
	var after: float = float(c1.eff_wind_side())
	_log("  [诊断] before=%s after=%s" % [str(before), str(after)])
	_check(before == -1.0 and after == 1.0, "C5-1 切变面 40m：侧风 -1 → +1（位置状态函数，诊断 %s/%s）" % [str(before), str(after)])

	# C5-2 换向力学：切变后漂移速度开始回补（侧风反向=风开始送回；本掷时长内位移仍向左，属设计内）
	var lat_min := 0.0
	var vel_at_shear := 99999.0
	var vel_end := 0.0
	var g2 := 0
	var probe: Object = CoreScript.new()
	probe.start_level(7)
	var prp: Rect2 = probe.paper_rect
	for k in 5:
		var mid_y: float = 0.5 - 0.5 * 0.2
		probe.add_fold(prp.position + prp.size * Vector2(0.92, mid_y - 0.23),
			prp.position + prp.size * Vector2(0.92, mid_y + 0.23))
	probe.finish_folds()
	probe.do_throw(30.0, 1.0)
	while String(probe.state) == "fly" and g2 < MAX_STEPS:
		probe.step(DELTA)
		lat_min = minf(lat_min, float(probe.lateral))
		if vel_at_shear > 9000.0 and probe.plane_pos.x >= 60.0 + 40.0 * 60.0:
			vel_at_shear = float(probe.lateral_vel)
		vel_end = float(probe.lateral_vel)
		g2 += 1
	_check(lat_min < -150.0 and vel_end > vel_at_shear + 30.0,
		"C5-2 切变后漂移速度回补：过切变面 %.0f → 落地 %.0f px/s（反向侧风 +48 预期）" % [vel_at_shear, vel_end])

	# C5-3 合理折法（无舵纯借风）：过关 + 高门 + 收益 23 = 3 + 6 + 14
	_check(probe.last_pass and probe.gate_hit and absf(float(probe.flight_distance) - 65.21) < 0.05,
		"C5-3 无舵纯借风 %.2fm 过关、高门命中（切变送回弹墙）" % float(probe.flight_distance))
	_check(probe.coins == 23 and probe.gate_coins == 3, "C5-3b 收益 23 = 门奖 3 + int(d/10) 6 + 过关奖 14")

	# C5-4 摆烂不可过：无折 65m 不足
	var lazy := _mk_l8(0, 30.0)
	_check(not lazy.last_pass and float(lazy.flight_distance) < 65.0,
		"C5-4 摆烂无折 %.1fm < 65 不可过" % float(lazy.flight_distance))

	# C5-5 前进/高度与侧风零耦合（有舵 vs 无舵 240 步逐位）
	var t1: Object = CoreScript.new()
	t1.start_level(7)
	var pr1: Rect2 = t1.paper_rect
	for k in 5:
		var mid_y1: float = 0.5 - 0.5 * 0.2
		t1.add_fold(pr1.position + pr1.size * Vector2(0.92, mid_y1 - 0.23),
			pr1.position + pr1.size * Vector2(0.92, mid_y1 + 0.23))
	t1.finish_folds()
	t1.do_throw(30.0, 1.0)
	var pa: Array = []
	var g5 := 0
	while String(t1.state) == "fly" and g5 < 240:
		t1.step(DELTA)
		pa.append(t1.plane_pos)
		g5 += 1
	var t2: Object = CoreScript.new()
	t2.start_level(7)
	var pr2: Rect2 = t2.paper_rect
	for k in 5:
		var mid_y2: float = 0.5 - 0.5 * 0.2
		t2.add_fold(pr2.position + pr2.size * Vector2(0.92, mid_y2 - 0.23),
			pr2.position + pr2.size * Vector2(0.92, mid_y2 + 0.23))
	t2.finish_folds()
	t2.do_throw(30.0, 1.0)
	var pb: Array = []
	var g6 := 0
	t2.lateral_input = 1.0
	while String(t2.state) == "fly" and g6 < 240:
		t2.step(DELTA)
		pb.append(t2.plane_pos)
		g6 += 1
	var same := pa.size() == pb.size()
	if same:
		for i in pa.size():
			var va: Vector2 = pa[i]
			var vb: Vector2 = pb[i]
			if va.distance_to(vb) > 1e-9:
				same = false
				break
	_check(same, "C5-5 侧风切变/顶风不改变前进与高度轨迹（%d 步逐位一致）" % pa.size())

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c5_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
