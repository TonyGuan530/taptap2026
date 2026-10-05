extends SceneTree
## demo-08 3D 阶段 C38（阶梯②新机制·L24 下沉峡谷）核心不变量（headless，固定 delta=1/60）：
## 规则变化：wind_up 竖直气流区（wind_up_x 米起 wind_up_len 米宽，wind_up ±px/s²，+升/-沉），
## 仅区内生效、独立于横向（B1 不耦合）。L24 = 逆风 1.25 × 下沉区 50-70m/-1600 × 角度二选一双门。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c38.gd（失败退出码非零）

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


func _mk_and_fly(level_idx: int, n: int, v: float, ang: float, pw: float) -> Object:
	var c: Object = CoreScript.new()
	c.start_level(level_idx)
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
	_log("demo-08 3D 阶段 C38 下沉峡谷测试开始")

	# C38-1 气流区分段函数：区前 0 / 区内 -1600 / 区后 0；LEVELS 24 关
	var c1: Object = CoreScript.new()
	c1.start_level(23)
	c1.plane_pos.x = 60.0 + 45.0 * 60.0
	var a_before: float = c1.updraft_accel()
	c1.plane_pos.x = 60.0 + 55.0 * 60.0
	var a_in: float = c1.updraft_accel()
	c1.plane_pos.x = 60.0 + 71.0 * 60.0
	var a_after: float = c1.updraft_accel()
	_check(a_before == 0.0 and a_in == -1600.0 and a_after == 0.0 and int(c1.LEVELS.size()) == 26,
		"C38-1 气流区分段：区外 0 / 区内 -1600 / 区外 0，26 关")

	# C38-2 高门线：4 折 v=0.2 27° → 过关吃高门漏低门，收益 24 = 3 + 7 + 14
	var hi: Object = _mk_and_fly(23, 4, 0.2, 27.0, 1.0)
	_check(hi.last_pass and hi.gate_hit and not hi.low_gate_hit,
		"C38-2 高门线过关吃高门（%.1fm）" % hi.flight_distance)
	_check(hi.coins == 24 and hi.gate_coins == 3,
		"C38-2b 收益 24 = 门奖 3 + int(d/10) 7 + 过关奖 14")

	# C38-3 低门线：4 折 v=0.2 26° → 过关吃低门漏高门（0.5° 翻转带：角度二选一）
	var lo: Object = _mk_and_fly(23, 4, 0.2, 26.0, 1.0)
	_check(lo.last_pass and lo.low_gate_hit and not lo.gate_hit,
		"C38-3 低门线过关吃低门（%.1fm）" % lo.flight_distance)

	# C38-4 摆烂对照：低力 45° 弱抛 → 远未达标判负（气流区不影响结算优先级）
	var lazy: Object = _mk_and_fly(23, 4, 0.2, 45.0, 0.3)
	_check(not lazy.last_pass,
		"C38-4 摆烂弱抛判负（%.1fm < 75m）" % lazy.flight_distance)

	# C38-5 风标签：逆风＋下沉气流区间（带俯冲穿越提示）
	var scene: Node = load("res://demo08_3d.tscn").instantiate()
	root.add_child(scene)
	for k in 3:
		await process_frame
	scene.core.start_level(23)
	var tag24: String = String(scene.wind_tag_text())
	scene.core.start_level(22)
	var tag23: String = String(scene.wind_tag_text())
	scene.queue_free()
	await process_frame
	_check(tag24 == "逆风 阻力 x1.25 ＋ 下沉气流 50-70 米（俯冲穿越）",
		"C38-5a L24 标签「%s」= 逆风＋下沉气流区间" % tag24)
	_check(tag23 == "顺风 恒定推力 ＋ 三段侧风 30/55m：←→←",
		"C38-5b L23 标签不变回归「%s」" % tag23)

	# C38-6 L1 静止锚：无气流区、标签空——新字段不触碰既有关
	var c5: Object = CoreScript.new()
	c5.start_level(0)
	c5.plane_pos.x = 60.0 + 55.0 * 60.0
	_check(float(c5.updraft_accel()) == 0.0 and absf(float(c5.side_wind_accel())) < 1e-6,
		"C38-6 L1 静止锚：无气流区/无正交侧风")

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c38_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
