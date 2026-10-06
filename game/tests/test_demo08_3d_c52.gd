extends SceneTree
## demo-08 3D 阶段 C52（大师篇·L31 风暴回廊）核心不变量（headless，固定 delta=1/60）：
## 纯既有机制组合（无新字段）：逆风 1.25 × 右推侧风 +60 × 谷 30-40/-2200 × 热流 44-58/+2800 × 摆动高门 62m/16m/+300/±360/3s。
## 大师篇开篇：能量/漂移/门相三重时序。28-35° 无舵宽窗吃门 24 币；D 补舵冲过门带漏门 21 币。
## L1-L30 逐位不变。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c52.gd（失败退出码非零）

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


func _mk_and_fly(n: int, v: float, ang: float, rudder: float, t_hold: float, pw: float = 1.0) -> Object:
	var c: Object = CoreScript.new()
	c.start_level(30)
	var pr: Rect2 = c.paper_rect
	for k in n:
		var mid_y: float = 0.5 - 0.5 * v
		c.add_fold(pr.position + pr.size * Vector2(0.92, mid_y - 0.23),
			pr.position + pr.size * Vector2(0.92, mid_y + 0.23))
	c.finish_folds()
	c.do_throw(ang, pw)
	var g := 0
	while String(c.state) == "fly" and g < MAX_STEPS:
		c.lateral_input = rudder if c.flight_time < t_hold else 0.0
		c.step(DELTA)
		g += 1
	return c


func _run() -> void:
	await process_frame
	_log("demo-08 3D 阶段 C52 风暴回廊测试开始")

	# C52-1 静态锚：双带 -2200/+2800、门摆 ±360/3s（右极/左极）、31 关
	var c1: Object = CoreScript.new()
	c1.start_level(30)
	c1.plane_pos.x = 60.0 + 35.0 * 60.0
	var a1: float = c1.updraft_accel()
	c1.plane_pos.x = 60.0 + 50.0 * 60.0
	var a2: float = c1.updraft_accel()
	_check(a1 == -2200.0 and a2 == 2800.0
		and absf(float(c1.gate_side_at(0.75)) - (300.0 + 360.0)) < 1e-6
		and absf(float(c1.gate_side_at(2.25)) - (300.0 - 360.0)) < 1e-6
		and int(c1.LEVELS.size()) == 38,
		"C52-1 静态锚：谷 -2200 / 热流 +2800 / 门摆 +300±360 / 38 关")

	# C52-2 配方：4 折 v=0.2 32° 无舵 → 过关吃摆动高门，24 = 3 + 7 + 14
	var good: Object = _mk_and_fly(4, 0.2, 32.0, 0.0, 0.0)
	_check(good.last_pass and good.gate_hit,
		"C52-2 配方过关吃摆动高门（%.1fm）" % good.flight_distance)
	_check(good.coins == 24 and good.gate_coins == 3,
		"C52-2b 收益 24 = 门奖 3 + int(d/10) 7 + 过关奖 14")

	# C52-3 补舵错档：同配方按 D 1.5s → 冲过门带漏门，21 = 0 + 7 + 14
	var push: Object = _mk_and_fly(4, 0.2, 28.0, 1.0, 1.5)
	_check(push.last_pass and not push.gate_hit and push.coins == 21,
		"C52-3 补舵档过关漏门 21 币（%.1fm）" % push.flight_distance)

	# C52-4 摆烂对照：弱抛判负
	var lazy: Object = _mk_and_fly(4, 0.2, 45.0, 0.0, 0.0, 0.3)
	_check(not lazy.last_pass, "C52-4 摆烂弱抛判负（%.1fm）" % lazy.flight_distance)

	# C52-5 标签：逆风＋侧风→＋双带四段
	var scene: Node = load("res://demo08_3d.tscn").instantiate()
	root.add_child(scene)
	for k in 3:
		await process_frame
	scene.core.start_level(30)
	var tag31: String = String(scene.wind_tag_text())
	scene.queue_free()
	await process_frame
	_check(tag31 == "逆风 阻力 x1.25 ＋ 侧风→ ＋ 下沉气流 30-40 米（俯冲穿越） ＋ 上升气流 44-58 米（乘流爬升）",
		"C52-5 L31 标签「%s」= 四段全展示" % tag31)

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c52_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
