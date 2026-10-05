extends SceneTree
## demo-08 3D 阶段 C15（阶梯①组合关·L16 逆风摆门峡）核心不变量（headless，固定 delta=1/60）：
## 纯既有机制组合（无新字段）：C8 双段切变三段侧风（-1→(32m)→+1→(58m)→-1）× C10 摆动门（+240±300/3.5s）。
## L1-L15 无新字段路径逐位不变。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c15.gd（失败退出码非零）

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


func _mk_l16(folds_n: int, angle: float, hold_t: float) -> Object:
	var c: Object = CoreScript.new()
	c.start_level(15)
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
	_log("demo-08 3D 阶段 C15 逆风摆门峡测试开始")

	# C15-1 双机制在位：三段侧风（shear 32/58）+ 摆门（±300/3.5s）
	var c1: Object = CoreScript.new()
	c1.start_level(15)
	var segs := {}
	for xm in [20.0, 40.0, 60.0]:
		c1.plane_pos.x = 60.0 + xm * 60.0
		segs[xm] = float(c1.eff_wind_side())
	_check(String(c1.wind_mode()) == "side" and segs[20.0] == -1.0 and segs[40.0] == 1.0 and segs[60.0] == -1.0
		and absf(float(c1.LEVELS[15].gate_swing) - 300.0) < 1e-9
		and absf(float(c1.LEVELS[15].gate_period) - 3.5) < 1e-9,
		"C15-1 双机制配置：三段侧风 -1/+1/-1 × 摆门 ±300/3.5s")

	# C15-2 摆门公式与位置无关（纯时间函数；侧风切变不影响门摆相位）
	var c2: Object = CoreScript.new()
	c2.start_level(15)
	c2.plane_pos.x = 60.0 + 10.0 * 60.0
	var g_at_low_x: float = float(c2.gate_side_at(1.0))
	c2.plane_pos.x = 60.0 + 45.0 * 60.0
	var g_at_high_x: float = float(c2.gate_side_at(1.0))
	_check(absf(g_at_low_x - g_at_high_x) < 1e-9,
		"C15-2 门摆相位与位置无关（纯时间函数，x=10m/45m 同值 %.1f）" % g_at_low_x)

	# C15-3 合理折法（无舵 30°）：过关 + 高门 + 收益 25 = 3 + 8 + 14
	var good := _mk_l16(5, 30.0, 0.0)
	_check(good.last_pass and good.gate_hit and absf(float(good.flight_distance) - 80.19) < 0.05,
		"C15-3 无舵借风 %.2fm 过关、高门命中（末位横位 %.0f px）" % [
			float(good.flight_distance), float(good.lateral)])
	_check(good.coins == 25 and good.gate_coins == 3, "C15-3b 收益 25 = 门奖 3 + int(d/10) 8 + 过关奖 14")

	# C15-4 摆烂不可过：无折 < 80
	var lazy := _mk_l16(0, 30.0, 0.0)
	_check(not lazy.last_pass and float(lazy.flight_distance) < 80.0,
		"C15-4 摆烂无折 %.1fm < 80 不可过" % float(lazy.flight_distance))

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c15_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
