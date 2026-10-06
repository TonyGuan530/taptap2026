extends SceneTree
## demo-08 3D 阶段 C57（大师篇·L35 终幕回廊=全叠收官）核心不变量（headless，固定 delta=1/60）：
## 纯既有机制组合（无新字段）：逆风 × 左推侧风 -60 × 深谷 30-38/-2000 × 热流 42-52/+2800 × 摆动高门 60m/18m/-240±360/3s。
## 三线结构：4×0.35@30° 与 4×0.5@34° 吃门 25 币；平折 4×0.2@30° 过关漏门 22 币；摆烂判负。
## 设计记录：原「终幕双门」（加低摆门）超约束——本模型无中空俯冲操控，低门不可达，诚实收敛为单摆门。
## L1-L34 逐位不变。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c57.gd（失败退出码非零）

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
	c.start_level(34)
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
	_log("demo-08 3D 阶段 C57 终幕回廊测试开始")

	# C57-1 静态锚：双带 -2000/+2800、门摆 -240±360/3s（两极）、35 关、无低门（收敛记录）
	var c1: Object = CoreScript.new()
	c1.start_level(34)
	c1.plane_pos.x = 60.0 + 34.0 * 60.0
	var a1: float = c1.updraft_accel()
	c1.plane_pos.x = 60.0 + 48.0 * 60.0
	var a2: float = c1.updraft_accel()
	_check(a1 == -2000.0 and a2 == 2800.0
		and absf(float(c1.gate_side_at(0.75)) - (-240.0 + 360.0)) < 1e-6
		and absf(float(c1.gate_side_at(2.25)) - (-240.0 - 360.0)) < 1e-6
		and int(c1.LEVELS.size()) == 37 and float(c1.LEVELS[34].get("low_gate_x", 0.0)) == 0.0,
		"C57-1 静态锚：谷 -2000 / 热流 +2800 / 门摆 -240±360 / 36 关 / 无低门")

	# C57-2 配方：4 折 v=0.35 30° 无舵 → 过关吃摆动高门，25 = 3 + 8 + 14
	var good: Object = _mk_and_fly(4, 0.35, 30.0, 0.0, 0.0)
	_check(good.last_pass and good.gate_hit,
		"C57-2 配方过关吃摆动高门（%.1fm）" % good.flight_distance)
	_check(good.coins == 25 and good.gate_coins == 3,
		"C57-2b 收益 25 = 门奖 3 + int(d/10) 8 + 过关奖 14")

	# C57-3 平折档：4 折 v=0.2 30° 无舵 → 过关漏门 22 = 0 + 8 + 14
	var flat: Object = _mk_and_fly(4, 0.2, 30.0, 0.0, 0.0)
	_check(flat.last_pass and not flat.gate_hit and flat.coins == 22,
		"C57-3 平折档过关漏门 22 币（%.1fm）" % flat.flight_distance)

	# C57-4 摆烂对照：弱抛判负
	var lazy: Object = _mk_and_fly(4, 0.2, 45.0, 0.0, 0.0, 0.3)
	_check(not lazy.last_pass, "C57-4 摆烂弱抛判负（%.1fm）" % lazy.flight_distance)

	# C57-5 标签：逆风＋侧风←＋双带四段
	var scene: Node = load("res://demo08_3d.tscn").instantiate()
	root.add_child(scene)
	for k in 3:
		await process_frame
	scene.core.start_level(34)
	var tag35: String = String(scene.wind_tag_text())
	scene.queue_free()
	await process_frame
	_check(tag35 == "逆风 阻力 x1.25 ＋ 侧风← ＋ 下沉气流 30-38 米（俯冲穿越） ＋ 上升气流 42-52 米（乘流爬升）",
		"C57-5 L35 标签「%s」= 四段全展示" % tag35)

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c57_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
