extends SceneTree
## demo-08 3D 阶段 C37（阶梯①组合关·L23 顺风S形 + 正交切变标签打磨）核心不变量（headless，固定 delta=1/60）：
## 纯既有机制组合（无新字段）：wind="tail"（顺风恒推）× side_wind=-60（正交左推）× 双段切变 30/55m（←→←）。
## 打磨：wind_tag_text 正交侧风显示切变段；wind="none"+side_wind（L20）不再返回空串。
## L1-L22 无新字段路径逐位不变。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c37.gd（失败退出码非零）

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
	_log("demo-08 3D 阶段 C37 顺风S形测试开始")

	# C37-1 静态锚：side_wind=-60 左推、起点切变符号 +1、LEVELS 23 关
	var c1: Object = CoreScript.new()
	c1.start_level(22)
	_check(float(c1.side_wind_accel()) == -60.0 and float(c1.shear_sign_flip()) == 1.0
		and int(c1.LEVELS.size()) == 28,
		"C37-1 静态锚：侧风 -60 左推 / 起点切变符号 +1 / 28 关")

	# C37-2 切变符号动态：越过 30m 翻 -1、再越 55m 翻回 +1（shear_sign_flip 位置状态函数）
	c1.plane_pos.x = 60.0 + 31.0 * 60.0
	var flip_mid: float = c1.shear_sign_flip()
	c1.plane_pos.x = 60.0 + 56.0 * 60.0
	var flip_end: float = c1.shear_sign_flip()
	_check(flip_mid == -1.0 and flip_end == 1.0,
		"C37-2 切变符号：30m 后 -1 / 55m 后 +1（正交侧风段向 ←→←）")

	# C37-3 配方：4 折均匀 v=0.2 30°、前 1.0s 按住 D → 70.2m 过关 + 高门命中 + 收益 24 = 3 + 7 + 14
	var c: Object = CoreScript.new()
	c.start_level(22)
	var pr: Rect2 = c.paper_rect
	for k in 4:
		var mid_y: float = 0.5 - 0.5 * 0.2
		c.add_fold(pr.position + pr.size * Vector2(0.92, mid_y - 0.23),
			pr.position + pr.size * Vector2(0.92, mid_y + 0.23))
	c.finish_folds()
	c.do_throw(30.0, 1.0)
	var g := 0
	while String(c.state) == "fly" and g < MAX_STEPS:
		c.lateral_input = 1.0 if c.flight_time < 1.0 else 0.0
		c.step(DELTA)
		g += 1
	_check(c.last_pass and c.gate_hit and c.flight_distance >= 70.0,
		"C37-3 配方过关吃高门（%.1fm ≥ 70m）" % c.flight_distance)
	_check(c.coins == 24 and c.gate_coins == 3,
		"C37-3b 收益 24 = 门奖 3 + int(d/10) 7 + 过关奖 14")

	# C37-4 无舵对照：中段左风带离 +240 门带 → 过关但漏门（挑战真实存在）
	var c3: Object = CoreScript.new()
	c3.start_level(22)
	var pr3: Rect2 = c3.paper_rect
	for k in 4:
		var mid_y3: float = 0.5 - 0.5 * 0.2
		c3.add_fold(pr3.position + pr3.size * Vector2(0.92, mid_y3 - 0.23),
			pr3.position + pr3.size * Vector2(0.92, mid_y3 + 0.23))
	c3.finish_folds()
	c3.do_throw(30.0, 1.0)
	var g3 := 0
	while String(c3.state) == "fly" and g3 < MAX_STEPS:
		c3.step(DELTA)
		g3 += 1
	_check(c3.last_pass and not c3.gate_hit and float(c3.lateral) < 0.0,
		"C37-4 无舵被中段左风带离漏门（lateral %.0f < 0，过关无门奖）" % c3.lateral)

	# C37-5 风标签：顺风恒推＋三段侧风段向；L20 无基础风正交标签不再为空
	var scene: Node = load("res://demo08_3d.tscn").instantiate()
	root.add_child(scene)
	for k in 3:
		await process_frame
	scene.core.start_level(22)
	var tag23: String = String(scene.wind_tag_text())
	scene.core.start_level(19)
	var tag20: String = String(scene.wind_tag_text())
	scene.core.start_level(21)
	var tag22: String = String(scene.wind_tag_text())
	scene.queue_free()
	await process_frame
	_check(tag23 == "顺风 恒定推力 ＋ 三段侧风 30/55m：←→←",
		"C37-5a L23 标签「%s」= 顺风恒推＋三段侧风段向" % tag23)
	_check(tag20 == "三段侧风 30/50m：→←→",
		"C37-5b L20 标签「%s」= 无基础风也显示正交侧风段向" % tag20)
	_check(tag22 == "顺风 恒定推力 ＋ 侧风→",
		"C37-5c L22 标签不变回归「%s」" % tag22)

	# C37-6 静止锚：L1 无风无侧风标签仍为空
	var c5: Object = CoreScript.new()
	c5.start_level(0)
	_check(absf(float(c5.side_wind_accel())) < 1e-6 and String(c5.wind_mode()) == "none",
		"C37-6 L1 静止锚：无正交侧风 / 无基础风")

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c37_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
