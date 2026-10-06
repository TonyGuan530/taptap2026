extends SceneTree
## demo-08 3D 阶段 C43（阶梯①组合关·L27 热流摆门）核心不变量（headless，固定 delta=1/60）：
## 纯既有机制组合（无新字段）：逆风 1.25 × 沉后托波形（谷 40-52m/-2500 + 热流 54-70m/+3000）× 摆动高门 74m/18m/±420/3.5s。
## 双时序三档：38-45° 过关吃门 25 币 / 30-33° 过关漏门 22 币（能量或相位差）/ 弱抛判负。
## L1-L26 无新字段路径逐位不变。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c43.gd（失败退出码非零）

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


func _mk_and_fly(n: int, v: float, ang: float, pw: float) -> Object:
	var c: Object = CoreScript.new()
	c.start_level(26)
	var pr: Rect2 = c.paper_rect
	for k in n:
		var mid_y: float = 0.5 - 0.5 * v
		c.add_fold(pr.position + pr.size * Vector2(0.92, mid_y - 0.23),
			pr.position + pr.size * Vector2(0.92, mid_y + 0.23))
	c.finish_folds()
	c.do_throw(ang, pw)
	var g := 0
	while String(c.state) == "fly" and g < MAX_STEPS:
		c.step(DELTA)
		g += 1
	return c


func _run() -> void:
	await process_frame
	_log("demo-08 3D 阶段 C43 热流摆门测试开始")

	# C43-1 静态锚：摆动高门 ±420/3.5（右极/左极）、双带 -2500/+3000、27 关
	var c1: Object = CoreScript.new()
	c1.start_level(26)
	c1.plane_pos.x = 60.0 + 45.0 * 60.0
	var a_sink: float = c1.updraft_accel()
	c1.plane_pos.x = 60.0 + 60.0 * 60.0
	var a_therm: float = c1.updraft_accel()
	_check(absf(float(c1.gate_side_at(0.875)) - 420.0) < 1e-6
		and absf(float(c1.gate_side_at(2.625)) + 420.0) < 1e-6
		and a_sink == -2500.0 and a_therm == 3000.0 and int(c1.LEVELS.size()) == 35,
		"C43-1 静态锚：门摆 ±420/3.5s / 双带 -2500/+3000 / 27 关")

	# C43-2 配方：4 折 v=0.2 40° → 过关吃摆动高门，收益 25 = 3 + 8 + 14
	var good: Object = _mk_and_fly(4, 0.2, 40.0, 1.0)
	_check(good.last_pass and good.gate_hit,
		"C43-2 配方过关吃摆动高门（%.1fm）" % good.flight_distance)
	_check(good.coins == 25 and good.gate_coins == 3,
		"C43-2b 收益 25 = 门奖 3 + int(d/10) 8 + 过关奖 14")

	# C43-3 时序错档：4 折 v=0.2 30° → 过关但漏门（能量或相位差），22 = 0 + 8 + 14
	var slow: Object = _mk_and_fly(4, 0.2, 30.0, 1.0)
	_check(slow.last_pass and not slow.gate_hit and slow.coins == 22,
		"C43-3 时序错档过关漏门 22 币（%.1fm）" % slow.flight_distance)

	# C43-4 摆烂对照：弱抛判负
	var lazy: Object = _mk_and_fly(4, 0.2, 45.0, 0.3)
	_check(not lazy.last_pass, "C43-4 摆烂弱抛判负（%.1fm）" % lazy.flight_distance)

	# C43-5 标签：与 L25 同波形（谷+热流双带）
	var scene: Node = load("res://demo08_3d.tscn").instantiate()
	root.add_child(scene)
	for k in 3:
		await process_frame
	scene.core.start_level(26)
	var tag27: String = String(scene.wind_tag_text())
	scene.queue_free()
	await process_frame
	_check(tag27 == "逆风 阻力 x1.25 ＋ 下沉气流 40-52 米（俯冲穿越） ＋ 上升气流 54-70 米（乘流爬升）",
		"C43-5 L27 标签「%s」= 逆风＋双区带（同 L25 波形）" % tag27)

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c43_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
