extends SceneTree
## demo-08 3D 阶段 C12（阶梯①组合关·L13 三风交汇）核心不变量（headless，固定 delta=1/60）：
## 纯既有机制三轴叠加（无新字段）：wind="head"（阻力×1.25）× side_wind=-60（左漂）× gate_swing ±5m/2.5s（门摆相位）。
## L1-L12 无新字段路径逐位不变。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c12.gd（失败退出码非零）

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


func _mk_l13(folds_v: Array, angle: float, hold_t: float) -> Object:
	var c: Object = CoreScript.new()
	c.start_level(12)
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
	_log("demo-08 3D 阶段 C12 三风交汇测试开始")

	# C12-1 三轴配置在位：head + side_wind -60 + gate_swing 300/2.5s
	var c1: Object = CoreScript.new()
	c1.start_level(12)
	_check(String(c1.wind_mode()) == "head" and absf(float(c1.side_wind_accel()) - (-60.0)) < 1e-9
		and absf(float(c1.LEVELS[12].gate_swing) - 300.0) < 1e-9
		and absf(float(c1.LEVELS[12].gate_period) - 2.5) < 1e-9,
		"C12-1 L13 三轴配置：逆风 × 左漂 -60 × 门摆 180±300/2.5s")

	# C12-2 门摆公式：t=0.625（四分之一相位）= 180+300=480；t=1.875 = 180-300=-120
	var c2: Object = CoreScript.new()
	c2.start_level(12)
	_check(absf(float(c2.gate_side_at(0.625)) - 480.0) < 1e-6 and absf(float(c2.gate_side_at(1.875)) + 120.0) < 1e-6,
		"C12-2 门摆公式：右极 480 / 左极 -120")

	# C12-3 不顶风不占位：无舵被吹左且错过门（漂移向左 vs 门窗 [-120,480] 偏右）
	var drift := _mk_l13([0.2, 0.2, 0.2, 0.2, 0.2], 30.0, 0.0)
	_check(float(drift.lateral) <= -150.0 and not drift.gate_hit,
		"C12-3 无舵漂左 %.0f px、高门错过（左漂 vs 右侧门窗）" % float(drift.lateral))

	# C12-4 合理折法+顶右风 0.8s：过关 + 高门 + 收益 22 = 3 + 5 + 14
	var good := _mk_l13([0.2, 0.2, 0.2, 0.2, 0.2], 30.0, 0.8)
	_check(good.last_pass and good.gate_hit and absf(float(good.flight_distance) - 55.13) < 0.05,
		"C12-4 顶风配方 %.2fm 过关、高门命中（横位 %.0f px）" % [float(good.flight_distance), float(good.lateral)])
	_check(good.coins == 22 and good.gate_coins == 3, "C12-4b 收益 22 = 门奖 3 + int(d/10) 5 + 过关奖 14")

	# C12-5 摆烂不可过：无折 < 55
	var lazy := _mk_l13([], 30.0, 0.0)
	_check(not lazy.last_pass and float(lazy.flight_distance) < 55.0,
		"C12-5 摆烂无折 %.1fm < 55 不可过" % float(lazy.flight_distance))

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c12_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
