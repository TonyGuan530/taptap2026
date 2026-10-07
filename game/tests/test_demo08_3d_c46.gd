extends SceneTree
## demo-08 3D 阶段 C46（阶梯①组合关·L30 终局峡谷=全机制终考）核心不变量（headless，固定 delta=1/60）：
## 纯既有机制组合（无新字段）：逆风 1.25 × 左推侧风 -60 × 谷 36-44m/-1600 × 热流 48-60m/+2400 × 左侧高门 66m/16m/-240。
## 顺流线（被动左漂入门带，28-36° 宽窗）；顶风右切则被带出门带（+356 出带）。L1-L29 逐位不变。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c46.gd（失败退出码非零）

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
	c.start_level(29)
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
	_log("demo-08 3D 阶段 C46 终局峡谷测试开始")

	# C46-1 静态锚：侧风 -60 左推、谷 -1600、热流 +2400、30 关
	var c1: Object = CoreScript.new()
	c1.start_level(29)
	c1.plane_pos.x = 60.0 + 40.0 * 60.0
	var a1: float = c1.updraft_accel()
	c1.plane_pos.x = 60.0 + 54.0 * 60.0
	var a2: float = c1.updraft_accel()
	_check(float(c1.side_wind_accel()) == -60.0 and a1 == -1600.0 and a2 == 2400.0
		and int(c1.LEVELS.size()) == 42,
		"C46-1 静态锚：侧风 -60 / 谷 -1600 / 热流 +2400 / 30 关")

	# C46-2 顺流配方：4 折 v=0.2 32° 无舵 → 过关吃左侧高门，24 = 3 + 7 + 14
	var go1: Object = _mk_and_fly(4, 0.2, 32.0, 0.0, 0.0)
	_check(go1.last_pass and go1.gate_hit,
		"C46-2 顺流过关吃左侧高门（%.1fm）" % go1.flight_distance)
	_check(go1.coins == 24 and go1.gate_coins == 3,
		"C46-2b 收益 24 = 门奖 3 + int(d/10) 7 + 过关奖 14")

	# C46-3 抗风失败模式：同配方按 D 1s → 被推离门带漏门（顺流课的反面）
	var fight: Object = _mk_and_fly(4, 0.2, 32.0, 1.0, 1.0)
	_check(fight.last_pass and not fight.gate_hit and float(fight.lateral) > 60.0,
		"C46-3 顶风右切出门带漏门（lat %.0f > 60）" % fight.lateral)

	# C46-4 摆烂对照：弱抛判负
	var lazy: Object = _mk_and_fly(4, 0.2, 45.0, 0.0, 0.0, 0.3)
	_check(not lazy.last_pass, "C46-4 摆烂弱抛判负（%.1fm）" % lazy.flight_distance)

	# C46-5 标签：四段全展示（逆风＋侧风←＋谷＋热流）
	var scene: Node = load("res://demo08_3d.tscn").instantiate()
	root.add_child(scene)
	for k in 3:
		await process_frame
	scene.core.start_level(29)
	var tag30: String = String(scene.wind_tag_text())
	scene.queue_free()
	await process_frame
	_check(tag30 == "逆风 阻力 x1.25 ＋ 侧风← ＋ 下沉气流 36-44 米（俯冲穿越） ＋ 上升气流 48-60 米（乘流爬升）",
		"C46-5 L30 标签「%s」= 四段全展示" % tag30)

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c46_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
