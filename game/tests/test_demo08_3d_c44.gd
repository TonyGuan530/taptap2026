extends SceneTree
## demo-08 3D 阶段 C44（阶梯①组合关·L28 谷风低门）核心不变量（headless，固定 delta=1/60）：
## 纯既有机制组合（无新字段）：逆风 1.25 × 正交侧风 +60（右推）× 下沉谷 36-46m/-2000 × 高门 28m/14m + 右侧低门 52m/8m/+240。
## 三轴同关。低线靠谷+侧风被动送入门带（克制不补舵：按 D 冲到 +920 出带、按 A 掉到 -350 出带）；
## 高线抬头吃门。L1-L27 无新字段路径逐位不变。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c44.gd（失败退出码非零）

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
	c.start_level(27)
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
	_log("demo-08 3D 阶段 C44 谷风低门测试开始")

	# C44-1 静态锚：侧风 +60 右推、谷内 -2000、28 关
	var c1: Object = CoreScript.new()
	c1.start_level(27)
	c1.plane_pos.x = 60.0 + 40.0 * 60.0
	_check(float(c1.side_wind_accel()) == 60.0 and float(c1.updraft_accel()) == -2000.0
		and int(c1.LEVELS.size()) == 42,
		"C44-1 静态锚：侧风 +60 / 谷内 -2000 / 42 关")

	# C44-2 低线（被动克制）：4 折 v=0.35 24° 无舵 → 过关吃右侧低门，23 = 3 + 6 + 14
	var lo: Object = _mk_and_fly(4, 0.35, 24.0, 0.0, 0.0)
	_check(lo.last_pass and lo.low_gate_hit and not lo.gate_hit,
		"C44-2 低线过关吃侧位低门（%.1fm）" % lo.flight_distance)
	_check(lo.coins == 23 and lo.gate_coins == 3,
		"C44-2b 收益 23 = 门奖 3 + int(d/10) 6 + 过关奖 14")

	# C44-3 高线：4 折 v=0.2 28° 无舵 → 过关吃高门漏低门
	var hi: Object = _mk_and_fly(4, 0.2, 28.0, 0.0, 0.0)
	_check(hi.last_pass and hi.gate_hit and not hi.low_gate_hit,
		"C44-3 高线过关吃高门（%.1fm）" % hi.flight_distance)

	# C44-4 补舵失败模式：按 D 3s 冲过头出带 / 按 A 1s 被带出带（低门漏）
	var over: Object = _mk_and_fly(4, 0.35, 24.0, 1.0, 3.0)
	var under: Object = _mk_and_fly(4, 0.35, 24.0, -1.0, 1.0)
	_check(over.last_pass and not over.low_gate_hit and float(over.lateral) > 540.0,
		"C44-4a 按 D 冲过头出门带（lat %.0f > 540）" % over.lateral)
	_check(under.last_pass and not under.low_gate_hit and float(under.lateral) < -60.0,
		"C44-4b 按 A 被带出带（lat %.0f < -60）" % under.lateral)

	# C44-5 摆烂对照：弱抛判负
	var lazy: Object = _mk_and_fly(4, 0.2, 45.0, 0.0, 0.0, 0.3)
	_check(not lazy.last_pass, "C44-5 摆烂弱抛判负（%.1fm）" % lazy.flight_distance)

	# C44-6 标签：逆风＋侧风→＋下沉谷三段
	var scene: Node = load("res://demo08_3d.tscn").instantiate()
	root.add_child(scene)
	for k in 3:
		await process_frame
	scene.core.start_level(27)
	var tag28: String = String(scene.wind_tag_text())
	scene.queue_free()
	await process_frame
	_check(tag28 == "逆风 阻力 x1.25 ＋ 侧风→ ＋ 下沉气流 36-46 米（俯冲穿越）",
		"C44-6 L28 标签「%s」= 逆风＋侧风＋下沉谷三段" % tag28)

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c44_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
