extends SceneTree
## demo-08 3D 阶段 C18（阶梯①组合关·L17 摆门斜风）核心不变量（headless，固定 delta=1/60）：
## 纯既有机制组合（无新字段）：wind="head"（阻力×1.25）× side_wind=-60（左漂）× gate_swing +300±240/4s（摆门）。
## L1-L16 无新字段路径逐位不变。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c18.gd（失败退出码非零）

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


func _mk_l17(folds_v: Array, angle: float, hold_t: float) -> Object:
	var c: Object = CoreScript.new()
	c.start_level(16)
	if folds_v.size() > 0:
		var pr: Rect2 = c.paper_rect
		for v in folds_v:
			var mid_y: float = 0.5 - 0.5 * float(v)
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
	_log("demo-08 3D 阶段 C18 摆门斜风测试开始")

	# C18-1 三轴配置在位：head + side_wind -60 + gate_swing 240/4s
	var c1: Object = CoreScript.new()
	c1.start_level(16)
	_check(String(c1.wind_mode()) == "head" and absf(float(c1.side_wind_accel()) - (-60.0)) < 1e-9
		and absf(float(c1.LEVELS[16].gate_swing) - 240.0) < 1e-9
		and absf(float(c1.LEVELS[16].gate_period) - 4.0) < 1e-9,
		"C18-1 L17 三轴配置：逆风 × 左漂 -60 × 摆门 +300±240/4s")

	# C18-2 摆门公式：t=1.0 右极 +540；t=3.0 左极 +60
	var c2: Object = CoreScript.new()
	c2.start_level(16)
	_check(absf(float(c2.gate_side_at(1.0)) - 540.0) < 1e-6 and absf(float(c2.gate_side_at(3.0)) - 60.0) < 1e-6,
		"C18-2 门摆公式：右极 540 / 左极 60（窗口 [60,540]）")

	# C18-3 顶右风配方：过关 + 高门 + 收益 23 = 3 + 6 + 14
	var good := _mk_l17([0.2, 0.2, 0.2, 0.2, 0.2], 30.0, 0.8)
	_check(good.last_pass and good.gate_hit and absf(float(good.flight_distance) - 60.18) < 0.05,
		"C18-3 顶风配方 %.2fm 过关、高门命中（末位横位 %.0f px）" % [float(good.flight_distance), float(good.lateral)])
	_check(good.coins == 23 and good.gate_coins == 3, "C18-3b 收益 23 = 门奖 3 + int(d/10) 6 + 过关奖 14")

	# C18-4 不顶风漂左漏门：距离不变（零耦合）但门错过、收益 17 = 6 + 14
	var lazy := _mk_l17([0.2, 0.2, 0.2, 0.2, 0.2], 30.0, 0.0)
	_check(lazy.last_pass and not lazy.gate_hit and absf(float(lazy.flight_distance) - float(good.flight_distance)) < 1e-9
		and lazy.coins == 20,
		"C18-4 不顶风 %.2fm 过关漏门（收益 20 = int(d/10) 6 + 过关奖 14，零耦合：距离与顶风逐位一致）" % float(lazy.flight_distance))

	# C18-5 摆烂不可过：无折 < 60
	var none2 := _mk_l17([], 30.0, 0.0)
	_check(not none2.last_pass and float(none2.flight_distance) < 60.0,
		"C18-5 摆烂无折 %.1fm < 60 不可过" % float(none2.flight_distance))

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c18_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
