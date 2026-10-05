extends SceneTree
## demo-08 3D 阶段 C36（阶梯①组合关·L22 顺风斜风）核心不变量（headless，固定 delta=1/60）：
## 纯既有机制组合（无新字段）：wind="tail"（顺风恒推）× side_wind=+60（正交侧风右推）× 左侧高门。
## 顺风提速使横向修正窗口变紧——顶风左切吃 -4m 横位高门是本关核心挑战。
## L1-L21 无新字段路径逐位不变。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c36.gd（失败退出码非零）

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
	_log("demo-08 3D 阶段 C36 顺风斜风测试开始")

	# C36-1 静态锚：side_wind=60 正交右推、无切变面（flip=+1）、LEVELS 22 关、门带 [-540,+60]
	var c1: Object = CoreScript.new()
	c1.start_level(21)
	_check(float(c1.side_wind_accel()) == 60.0 and float(c1.shear_sign_flip()) == 1.0
		and int(c1.LEVELS.size()) == 27 and absf(float(c1.wind_side3()) + 1.0) < 1e-6,
		"C36-1 静态锚：侧风 +60 右推 / 切变符号 +1 / 27 关 / wind_side3 回退默认 -1")

	# C36-2 配方：4 折均匀 v=0.2 35°、前 1.0s 按住 A → 65.2m 过关 + 高门命中 + 收益 23 = 3 + 6 + 14
	var c: Object = CoreScript.new()
	c.start_level(21)
	var pr: Rect2 = c.paper_rect
	for k in 4:
		var mid_y: float = 0.5 - 0.5 * 0.2
		c.add_fold(pr.position + pr.size * Vector2(0.92, mid_y - 0.23),
			pr.position + pr.size * Vector2(0.92, mid_y + 0.23))
	c.finish_folds()
	c.do_throw(35.0, 1.0)
	var g := 0
	while String(c.state) == "fly" and g < MAX_STEPS:
		c.lateral_input = -1.0 if c.flight_time < 1.0 else 0.0
		c.step(DELTA)
		g += 1
	_check(c.last_pass and c.gate_hit and c.flight_distance >= 65.0,
		"C36-2 配方过关吃高门（%.1fm ≥ 65m）" % c.flight_distance)
	_check(c.coins == 23 and c.gate_coins == 3,
		"C36-2b 收益 23 = 门奖 3 + int(d/10) 6 + 过关奖 14")

	# C36-3 无舵对照：不按 A → 侧风右推带走，高门漏掉（横位出带 [-540,+60]），侧风挑战真实存在
	var c3: Object = CoreScript.new()
	c3.start_level(21)
	var pr3: Rect2 = c3.paper_rect
	for k in 4:
		var mid_y3: float = 0.5 - 0.5 * 0.2
		c3.add_fold(pr3.position + pr3.size * Vector2(0.92, mid_y3 - 0.23),
			pr3.position + pr3.size * Vector2(0.92, mid_y3 + 0.23))
	c3.finish_folds()
	c3.do_throw(35.0, 1.0)
	var g3 := 0
	while String(c3.state) == "fly" and g3 < MAX_STEPS:
		c3.step(DELTA)
		g3 += 1
	_check(not c3.gate_hit and float(c3.lateral) > 60.0,
		"C36-3 无舵被右风带走漏门（lateral %.0f > 60 出带）" % c3.lateral)

	# C36-4 风标签：顺风恒定推力 ＋ 侧风→
	var scene: Node = load("res://demo08_3d.tscn").instantiate()
	root.add_child(scene)
	for k in 3:
		await process_frame
	scene.core.start_level(21)
	var tag: String = String(scene.wind_tag_text())
	scene.queue_free()
	await process_frame
	_check(tag == "顺风 恒定推力 ＋ 侧风→", "C36-4 风标签「%s」= 顺风恒推＋侧风右推" % tag)

	# C36-5 静止锚：L1 无风无侧风标签为空、低门恒 0——新增关不影响既有配置
	var c5: Object = CoreScript.new()
	c5.start_level(0)
	_check(absf(float(c5.low_gate_side_at(0.0))) < 1e-6 and float(c5.side_wind_accel()) == 0.0,
		"C36-5 L1 静止锚：低门横位 0 / 无正交侧风")

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c36_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
