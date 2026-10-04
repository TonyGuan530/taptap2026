extends SceneTree
## demo-08 3D 阶段 C8（阶梯②双段切变·L10 S 形走廊）核心不变量（headless，固定 delta=1/60）：
## 规则变化 C8：LEVELS 可选 shear_x2/wind_side3（第二次切变，0=无）；eff_wind_side 三段式。
## L10：-1 →(30m)→ +1 →(50m)→ -1；高门 42m/+5m 横位落在 +1 段。L1-L9 无该字段路径逐位不变。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c8.gd（失败退出码非零）

const CoreScript := preload("res://demo08_3d/flight_core.gd")
const DELTA := 1.0 / 60.0
const MAX_STEPS := 2000

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


func _mk_l10(folds_n: int, angle: float, hold_t: float) -> Object:
	var c: Object = CoreScript.new()
	c.start_level(9)
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
		c.lateral_input = 1.0 if c.flight_time < hold_t else 0.0
		c.step(DELTA)
		g += 1
	return c


func _run() -> void:
	await process_frame
	_log("demo-08 3D 阶段 C8 双段切变测试开始")

	# C8-1 三段力学：eff_wind_side 在 20/40/60m 处分别为 -1/+1/-1
	var c1: Object = CoreScript.new()
	c1.start_level(9)
	var segs := {}
	for xm in [20.0, 40.0, 60.0]:
		c1.plane_pos.x = 60.0 + xm * 60.0
		segs[xm] = float(c1.eff_wind_side())
	_check(segs[20.0] == -1.0 and segs[40.0] == 1.0 and segs[60.0] == -1.0,
		"C8-1 三段切变：20m=%s 40m=%s 60m=%s" % [str(segs[20.0]), str(segs[40.0]), str(segs[60.0])])

	# C8-2 S 形横向：无舵先左漂（-1 段），切变后右漂（+1 段），二次切变后再左漂
	var lat_min := 0.0
	var lat_max := 0.0
	var lat_end := 0.0
	var lat_at_50m := 99999.0
	var g2 := 0
	var probe: Object = CoreScript.new()
	probe.start_level(9)
	var prp: Rect2 = probe.paper_rect
	for k in 5:
		var mid_y: float = 0.5 - 0.5 * 0.2
		probe.add_fold(prp.position + prp.size * Vector2(0.92, mid_y - 0.23),
			prp.position + prp.size * Vector2(0.92, mid_y + 0.23))
	probe.finish_folds()
	probe.do_throw(30.0, 1.0)
	while String(probe.state) == "fly" and g2 < MAX_STEPS:
		probe.step(DELTA)
		var lat: float = float(probe.lateral)
		lat_min = minf(lat_min, lat)
		lat_max = maxf(lat_max, lat)
		lat_end = lat
		if lat_at_50m > 9000.0 and probe.plane_pos.x >= 60.0 + 50.2 * 60.0:
			lat_at_50m = lat
		g2 += 1
	_check(lat_min < -150.0 and lat_at_50m > lat_min + 80.0 and lat_end < lat_at_50m,
		"C8-2 S 形三段签名：最低 %.0f → 50m 回补 %.0f → 末位 %.0f（跌/回补/再跌）" % [
			lat_min, lat_at_50m, lat_end])

	# C8-3 合理折法（顶右风 0.6s 占位右线）：过关 + 高门 + 收益 24 = 3 + 7 + 14
	var good := _mk_l10(5, 30.0, 0.6)
	_check(good.last_pass and good.gate_hit and absf(float(good.flight_distance) - 75.09) < 0.05,
		"C8-3 顶风配方 %.2fm 过关、高门命中（末位 %.0f px）" % [float(good.flight_distance), float(good.lateral)])
	_check(good.coins == 24 and good.gate_coins == 3, "C8-3b 收益 24 = 门奖 3 + int(d/10) 7 + 过关奖 14")

	# C8-4 摆烂不可过：无折 < 75
	var lazy := _mk_l10(0, 30.0, 0.6)
	_check(not lazy.last_pass and float(lazy.flight_distance) < 75.0,
		"C8-4 摆烂无折 %.1fm < 75 不可过" % float(lazy.flight_distance))

	# C8-5 前进/高度与侧风零耦合（有舵 vs 无舵 260 步逐位）
	var t1: Object = CoreScript.new()
	t1.start_level(9)
	var pr1: Rect2 = t1.paper_rect
	for k in 5:
		var mid_y1: float = 0.5 - 0.5 * 0.2
		t1.add_fold(pr1.position + pr1.size * Vector2(0.92, mid_y1 - 0.23),
			pr1.position + pr1.size * Vector2(0.92, mid_y1 + 0.23))
	t1.finish_folds()
	t1.do_throw(30.0, 1.0)
	var pa: Array = []
	var g5 := 0
	while String(t1.state) == "fly" and g5 < 260:
		t1.step(DELTA)
		pa.append(t1.plane_pos)
		g5 += 1
	var t2: Object = CoreScript.new()
	t2.start_level(9)
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
	while String(t2.state) == "fly" and g6 < 260:
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
	_check(same, "C8-5 双段切变/顶风不改变前进与高度轨迹（%d 步逐位一致）" % pa.size())

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c8_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
