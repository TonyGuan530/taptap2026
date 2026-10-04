extends SceneTree
## demo-08 3D 阶段 C11（阶梯①组合关·L12 乘风摆门）核心不变量（headless，固定 delta=1/60）：
## 纯既有机制组合（无新字段）：wind="side"（C2 侧风漂移）× gate_swing（C10 摆动门相位）。
## 漂移线与门摆相位交汇即命中；L1-L11 无新字段路径逐位不变。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c11.gd（失败退出码非零）

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


func _mk_l12(folds_v: Array, angle: float, hold_t: float) -> Object:
	var c: Object = CoreScript.new()
	c.start_level(11)
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
	_log("demo-08 3D 阶段 C11 乘风摆门测试开始")

	# C11-1 组合配置在位：wind=side（+1）且 gate_swing=360/period=4
	var c1: Object = CoreScript.new()
	c1.start_level(11)
	_check(String(c1.wind_mode()) == "side" and absf(float(c1.wind_side()) - 1.0) < 1e-9
		and absf(float(c1.LEVELS[11].gate_swing) - 360.0) < 1e-9,
		"C11-1 L12 双机制配置：侧风 +1 × 摆门 ±6m/4s")

	# C11-2 组合配方（无舵纯乘风）：过关 + 高门 + 收益 21 = 3 + 6 + 12
	var good := _mk_l12([0.35, 0.35, 0.35, 0.35, 0.35], 35.0, 0.0)
	_check(good.last_pass and good.gate_hit and absf(float(good.flight_distance) - 60.28) < 0.05,
		"C11-2 无舵纯乘风 %.2fm 过关、高门命中（漂移线与门摆相位交汇）" % float(good.flight_distance))
	_check(good.coins == 21 and good.gate_coins == 3, "C11-2b 收益 21 = 门奖 3 + int(d/10) 6 + 过关奖 12")

	# C11-3 漂移线可调：顶右风 1.2s vs 无舵，横位差 > 100（相位关系随之改变，机制可操作）
	var alt := _mk_l12([0.35, 0.35, 0.35, 0.35, 0.35], 35.0, 1.2)
	var lat_diff: float = absf(float(alt.lateral) - float(good.lateral))
	_check(lat_diff > 100.0, "C11-3 漂移线可调：无舵 %.0f vs 顶风 %.0f（差 %.0f px）" % [
		float(good.lateral), float(alt.lateral), lat_diff])

	# C11-4 摆烂不可过：无折 < 60
	var lazy := _mk_l12([], 30.0, 0.0)
	_check(not lazy.last_pass and float(lazy.flight_distance) < 60.0,
		"C11-4 摆烂无折 %.1fm < 60 不可过" % float(lazy.flight_distance))

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c11_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
