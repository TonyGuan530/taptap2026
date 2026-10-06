extends SceneTree
## demo-08 3D 阶段 C54（大师篇·L33 热流之巅）核心不变量（headless，固定 delta=1/60）：
## 纯既有机制组合（无新字段）：逆风 × 深谷 34-44/-2200 × 强热流 46-60/+3200 × 超高门 60m/24m（全系列最高门）。
## 精确高度课：出口高度按角度阈值判别（4×0.2 需 ≥34° 才过 24m 线），两档 24/21 币。
## L1-L32 逐位不变。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c54.gd（失败退出码非零）

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
	c.start_level(32)
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
	_log("demo-08 3D 阶段 C54 热流之巅测试开始")

	# C54-1 静态锚：双带 -2200/+3200、门高 24m（全系列最高）、33 关
	var c1: Object = CoreScript.new()
	c1.start_level(32)
	c1.plane_pos.x = 60.0 + 38.0 * 60.0
	var a1: float = c1.updraft_accel()
	c1.plane_pos.x = 60.0 + 52.0 * 60.0
	var a2: float = c1.updraft_accel()
	_check(a1 == -2200.0 and a2 == 3200.0 and float(c1.LEVELS[32].gate_h) == 24.0
		and int(c1.LEVELS.size()) == 33,
		"C54-1 静态锚：谷 -2200 / 热流 +3200 / 门高 24m 全系列最高 / 33 关")

	# C54-2 配方：4 折 v=0.2 36° → 过关吃超高门，24 = 3 + 7 + 14
	var good: Object = _mk_and_fly(4, 0.2, 36.0)
	_check(good.last_pass and good.gate_hit,
		"C54-2 配方过关吃超高门（%.1fm，出口高度达标）" % good.flight_distance)
	_check(good.coins == 24 and good.gate_coins == 3,
		"C54-2b 收益 24 = 门奖 3 + int(d/10) 7 + 过关奖 14")

	# C54-3 骑歪档：4 折 v=0.2 32° → 过关但出口高度差 1m 漏门，21 = 0 + 7 + 14
	var low: Object = _mk_and_fly(4, 0.2, 32.0)
	_check(low.last_pass and not low.gate_hit and low.coins == 21,
		"C54-3 骑歪档过关漏门 21 币（%.1fm）" % low.flight_distance)

	# C54-4 摆烂对照：弱抛判负
	var lazy: Object = _mk_and_fly(4, 0.2, 45.0, 0.3)
	_check(not lazy.last_pass, "C54-4 摆烂弱抛判负（%.1fm）" % lazy.flight_distance)

	# C54-5 标签：逆风＋双带
	var scene: Node = load("res://demo08_3d.tscn").instantiate()
	root.add_child(scene)
	for k in 3:
		await process_frame
	scene.core.start_level(32)
	var tag33: String = String(scene.wind_tag_text())
	scene.queue_free()
	await process_frame
	_check(tag33 == "逆风 阻力 x1.25 ＋ 下沉气流 34-44 米（俯冲穿越） ＋ 上升气流 46-60 米（乘流爬升）",
		"C54-5 L33 标签「%s」= 逆风＋双带" % tag33)

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c54_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
