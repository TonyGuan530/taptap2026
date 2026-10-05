extends SceneTree
## demo-08 3D 阶段 C13（阶梯①组合关·L14 逆风三段走廊）核心不变量（headless，固定 delta=1/60）：
## 规则变化 C13：切变面同样作用于正交侧风——每越过一个已配置切变面，side_wind 符号翻转一次。
## L14：逆风 1.25× + 三段侧风（-60 →(35m)→ +60 →(60m)→ -60），高门 48m/+2m 横位（设计调优后窗口 [-180,420]）。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c13.gd（失败退出码非零）

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


## 位置窗顶风策略：35m 切变进 +1 段后按住 D，60m 回 -1 段松手
func _mk_l14(folds_n: int, angle: float, use_hold: bool) -> Object:
	var c: Object = CoreScript.new()
	c.start_level(13)
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
		var in_window: bool = c.plane_pos.x >= 60.0 + 30.2 * 60.0 and c.plane_pos.x < 60.0 + 61.8 * 60.0
		c.lateral_input = 1.0 if (use_hold and in_window) else 0.0
		c.step(DELTA)
		g += 1
	return c


func _run() -> void:
	await process_frame
	_log("demo-08 3D 阶段 C13 逆风三段走廊测试开始")

	# C13-1 符号翻转函数：L14 在 20/40/50/70m 处翻转系数 +1/-1/-1/+1（侧风 -60×系数 → 左/右/右/左 wait 系数×-60）
	var c1: Object = CoreScript.new()
	c1.start_level(13)
	var segs := {}
	for xm in [20.0, 40.0, 50.0, 70.0]:
		c1.plane_pos.x = 60.0 + xm * 60.0
		segs[xm] = float(c1.shear_sign_flip())
	_check(segs[20.0] == 1.0 and segs[40.0] == -1.0 and segs[50.0] == -1.0 and segs[70.0] == 1.0,
		"C13-1 符号翻转：20m=%s 40m=%s 50m=%s 70m=%s（侧风 -60 → 左/右/右/左三段）" % [
			str(segs[20.0]), str(segs[40.0]), str(segs[50.0]), str(segs[70.0])])

	# C13-2 三段漂移形态（无舵）：左漂 → 切变后右送 → 末段再左漂（同 C8 三段签名 + 逆风拖拽）
	var lat_min := 0.0
	var lat_at_50 := 99999.0
	var lat_end := 0.0
	var g2 := 0
	var probe: Object = CoreScript.new()
	probe.start_level(13)
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
		if lat_at_50 > 9000.0 and probe.plane_pos.x >= 60.0 + 50.2 * 60.0:
			lat_at_50 = lat
		lat_end = lat
		g2 += 1
	_check(lat_min < -120.0 and lat_at_50 > lat_min + 60.0 and lat_end < lat_at_50,
		"C13-2 三段漂移签名：最低 %.0f → 50m 回补 %.0f → 末位 %.0f（跌/回补/再跌，逆风拖拽版）" % [
			lat_min, lat_at_50, lat_end])

	# C13-3 合理折法+位置窗顶风：过关 + 高门 + 收益 24 = 3 + 7 + 14
	var good := _mk_l14(5, 30.0, true)
	_check(good.last_pass and good.gate_hit and absf(float(good.flight_distance) - 70.08) < 0.05,
		"C13-3 位置窗顶风 %.2fm 过关、高门命中（末位 %.0f px）" % [float(good.flight_distance), float(good.lateral)])
	_check(good.coins == 24 and good.gate_coins == 3, "C13-3b 收益 24 = 门奖 3 + int(d/10) 7 + 过关奖 14")

	# C13-4 摆烂不可过：无折 < 70
	var lazy := _mk_l14(0, 30.0, true)
	_check(not lazy.last_pass and float(lazy.flight_distance) < 70.0,
		"C13-4 摆烂无折 %.1fm < 70 不可过" % float(lazy.flight_distance))

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c13_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
