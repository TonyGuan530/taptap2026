extends SceneTree
## demo-08 3D 阶段 C35（阶梯①组合关·L21 顺风摆门）核心不变量（headless，固定 delta=1/60）：
## 纯既有机制组合（无新字段）：wind="tail"（顺风推力）× low_gate_swing ±240/3s（低门 55m 摆动）。
## L1-L20 无新字段路径逐位不变。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c35.gd（失败退出码非零）

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


func _run() -> void:
	await process_frame
	_log("demo-08 3D 阶段 C35 顺风摆门测试开始")

	# C35-1 低门摆动公式：side 120 ± 240，周期 3s——t=0.75 右极 360，t=2.25 左极 -120
	var c1: Object = CoreScript.new()
	c1.start_level(20)
	_check(absf(float(c1.low_gate_side_at(0.75)) - 360.0) < 1e-6
		and absf(float(c1.low_gate_side_at(2.25)) + 120.0) < 1e-6,
		"C35-1 低门摆动公式：右极 360 / 左极 -120（窗口 [-120,360]）")

	# C35-2 配方：5 折 v=-0.5 30° 无舵 → 70.2m 过关 + 低门命中 + 收益 24 = 3 + 7 + 14
	var c: Object = CoreScript.new()
	c.start_level(20)
	var pr: Rect2 = c.paper_rect
	for k in 5:
		var mid_y: float = 0.5 - 0.5 * -0.5
		c.add_fold(pr.position + pr.size * Vector2(0.92, mid_y - 0.23),
			pr.position + pr.size * Vector2(0.92, mid_y + 0.23))
	c.finish_folds()
	c.do_throw(30.0, 1.0)
	var g := 0
	while String(c.state) == "fly" and g < MAX_STEPS:
		c.step(DELTA)
		g += 1
	_check(c.last_pass and c.low_gate_hit and absf(float(c.flight_distance) - 70.2) < 0.1,
		"C35-2 配方 %.1fm 过关、低门命中（横位 %.0f px ∈ 窗口 [-120,360]）" % [
			float(c.flight_distance), float(c.lateral)])
	_check(int(c.coins) == 24 and int(c.gate_coins) == 3, "C35-2b 收益 24 = 门奖 3 + int(d/10) 7 + 过关奖 14")

	# C35-3 不顶风不俯冲（角度抬高）→ 漏低门但可过关
	var c3: Object = CoreScript.new()
	c3.start_level(20)
	var pr3: Rect2 = c3.paper_rect
	for k in 5:
		var mid_y3: float = 0.5 - 0.5 * -0.5
		c3.add_fold(pr3.position + pr3.size * Vector2(0.92, mid_y3 - 0.23),
			pr3.position + pr3.size * Vector2(0.92, mid_y3 + 0.23))
	c3.finish_folds()
	c3.do_throw(45.0, 1.0)
	var g3 := 0
	while String(c3.state) == "fly" and g3 < MAX_STEPS:
		c3.step(DELTA)
		g3 += 1
	_check(c3.last_pass and not c3.low_gate_hit,
		"C35-3 高角度 %.1fm 过关但漏低门（y55 超标，飞行弧线高于门顶）" % float(c3.flight_distance))

	# C35-4 静止锚：L1 低门无摆动字段 → low_gate_side_at 恒 0
	var c4: Object = CoreScript.new()
	c4.start_level(0)
	var static_ok := true
	for t in [0.0, 0.75, 1.5, 2.25]:
		if absf(float(c4.low_gate_side_at(t))) > 1e-12:
			static_ok = false
	_check(static_ok, "C35-4 静止关卡低门横位恒 0（低门摆动字段隔离）")

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c35_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
