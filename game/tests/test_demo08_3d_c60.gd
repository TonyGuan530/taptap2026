extends SceneTree
## demo-08 3D 阶段 C60（阶梯②新门类型·L36 时机走廊）核心不变量（headless，固定 delta=1/60）：
## 规则变化（已记录）：gate_open_t0/t1（秒）高门开启时间窗——窗内穿越才可判定，窗外视作未设门；
## 两字段均 0（缺省）= 常开，既有 35 关路径逐位不变。门体飞行中随开启态显隐。
## 三态：窗内命中 23 币 / 窗外漏门 20 币 / 摆烂判负。36 关。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c60.gd（失败退出码非零）

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


func _mk_and_fly(n: int, v: float, ang: float, pw: float = 1.0) -> Object:
	var c: Object = CoreScript.new()
	c.start_level(35)
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
	_log("demo-08 3D 阶段 C60 时机走廊测试开始")

	# C60-1 静态锚：时机窗 2.0-3.2s、36 关、gate_open() 三态（窗前/窗内/窗后）
	var c1: Object = CoreScript.new()
	c1.start_level(35)
	c1.flight_time = 1.0
	var t_early: bool = c1.gate_open()
	c1.flight_time = 2.5
	var t_in: bool = c1.gate_open()
	c1.flight_time = 3.5
	var t_late: bool = c1.gate_open()
	_check(t_early == false and t_in == true and t_late == false and int(c1.LEVELS.size()) == 42,
		"C60-1 时机窗三态：窗前闭 / 窗内开 / 窗后闭，42 关")

	# C60-2 常开回归：L1（无时机字段）任意时刻 gate_open 恒真
	c1.start_level(0)
	c1.flight_time = 0.5
	var o1: bool = c1.gate_open()
	c1.flight_time = 13.0
	var o2: bool = c1.gate_open()
	_check(o1 and o2, "C60-2 L1 常开回归（缺省路径逐位不变）")

	# C60-3 窗内配方：3 折 v=0.2 28° → 过关吃时机门，23 = 3 + 6 + 14
	var good: Object = _mk_and_fly(3, 0.2, 28.0)
	_check(good.last_pass and good.gate_hit,
		"C60-3 窗内配方过关吃时机门（%.1fm）" % good.flight_distance)
	_check(good.coins == 23 and good.gate_coins == 3,
		"C60-3b 收益 23 = 门奖 3 + int(d/10) 6 + 过关奖 14")

	# C60-4 窗外晚到：4 折 v=0.2 54° 陡抛 → 窗后（t40≈3.32s）穿越漏门，过关 20 = 0 + 6 + 14
	var late: Object = _mk_and_fly(4, 0.2, 54.0)
	_check(late.last_pass and not late.gate_hit and late.coins == 20,
		"C60-4 窗外（晚到）漏门 20 币（%.1fm）" % late.flight_distance)

	# C60-5 摆烂对照：弱抛判负
	var lazy: Object = _mk_and_fly(3, 0.2, 45.0, 0.3)
	_check(not lazy.last_pass, "C60-5 摆烂弱抛判负（%.1fm）" % lazy.flight_distance)

	# C60-6 场景层：飞行中门体随开启态显隐（真实飞行驱动，30° 配方 t40≈2.4s 在窗内）
	var scene: Node = load("res://demo08_3d.tscn").instantiate()
	root.add_child(scene)
	for k in 3:
		await process_frame
	var core: Object = scene.core
	core.unlocked = 35
	scene._on_level_pressed(35)   # fold 态 + _apply_level_props 建门
	var pr6: Rect2 = core.paper_rect
	for k in 3:
		var mid6: float = 0.5 - 0.5 * 0.2
		core.add_fold(pr6.position + pr6.size * Vector2(0.92, mid6 - 0.23),
			pr6.position + pr6.size * Vector2(0.92, mid6 + 0.23))
	core.finish_folds()
	core.do_throw(30.0, 1.0)
	await process_frame
	# 窗前（t<2.0）：门体隐藏
	while core.flight_time < 0.8 and String(core.state) == "fly":
		await process_frame
	var v_early: bool = scene.high_gate.visible
	# 窗内（2.0-3.2s）：门体显示
	while core.flight_time < 2.5 and String(core.state) == "fly":
		await process_frame
	var v_mid: bool = scene.high_gate.visible
	# 窗后（t>3.2）：门体隐藏
	while core.flight_time < 3.4 and String(core.state) == "fly":
		await process_frame
	var v_late: bool = scene.high_gate.visible
	_check(v_early == false and v_mid == true and v_late == false,
		"C60-6 门体显隐三态：窗前 %s / 窗内 %s / 窗后 %s" % [str(v_early), str(v_mid), str(v_late)])
	scene.queue_free()
	await process_frame

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c60_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
