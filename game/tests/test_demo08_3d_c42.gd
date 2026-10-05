extends SceneTree
## demo-08 3D 阶段 C42（阶梯①组合关·L26 谷底摆门）核心不变量（headless，固定 delta=1/60）：
## 纯既有机制组合（无新字段）：逆风 1.25 × 下沉谷 40-52m/-2000 × 摆动低门 58m/top10/±420/3s。
## 双线：俯冲穿谷数拍吃低门（≈28°）与抬头吃高门（≈30°+）弹道分岔；25-27° 吃门不过关（门奖保留）。
## L1-L25 无新字段路径逐位不变。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c42.gd（失败退出码非零）

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
	c.start_level(25)
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
	_log("demo-08 3D 阶段 C42 谷底摆门测试开始")

	# C42-1 静态锚：摆动公式（右极 +420 / 左极 -420）、LEVELS 26 关、谷内 -2000
	var c1: Object = CoreScript.new()
	c1.start_level(25)
	c1.plane_pos.x = 60.0 + 45.0 * 60.0
	_check(absf(float(c1.low_gate_side_at(0.75)) - 420.0) < 1e-6
		and absf(float(c1.low_gate_side_at(2.25)) + 420.0) < 1e-6
		and float(c1.updraft_accel()) == -2000.0 and int(c1.LEVELS.size()) == 26,
		"C42-1 静态锚：低门摆 ±420/3s / 谷内 -2000 / 26 关")

	# C42-2 低线配方：4 折 v=0.35 28° → 过关吃摆动低门，收益 24 = 3 + 7 + 14
	var lo: Object = _mk_and_fly(4, 0.35, 28.0, 1.0)
	_check(lo.last_pass and lo.low_gate_hit and not lo.gate_hit,
		"C42-2 低线过关吃摆动低门（%.1fm）" % lo.flight_distance)
	_check(lo.coins == 24 and lo.gate_coins == 3,
		"C42-2b 收益 24 = 门奖 3 + int(d/10) 7 + 过关奖 14")

	# C42-3 高线配方：4 折 v=0.35 30° → 过关吃高门漏低门（弹道分岔互斥）
	var hi: Object = _mk_and_fly(4, 0.35, 30.0, 1.0)
	_check(hi.last_pass and hi.gate_hit and not hi.low_gate_hit,
		"C42-3 高线过关吃高门（%.1fm）" % hi.flight_distance)

	# C42-4 部分计分：4 折 v=0.35 26° → 吃低门但滑程不足判负，门奖 3 保留
	var mid: Object = _mk_and_fly(4, 0.35, 26.0, 1.0)
	_check(not mid.last_pass and mid.low_gate_hit and mid.coins == 3,
		"C42-4 吃门不过关保留门奖 3（%.1fm < 70m）" % mid.flight_distance)

	# C42-5 摆烂对照：弱抛判负
	var lazy: Object = _mk_and_fly(4, 0.2, 45.0, 0.3)
	_check(not lazy.last_pass, "C42-5 摆烂弱抛判负（%.1fm）" % lazy.flight_distance)

	# C42-6 标签与结算：L26 标签含下沉谷无热流；低线结算带谷出口高度
	var scene: Node = load("res://demo08_3d.tscn").instantiate()
	root.add_child(scene)
	for k in 3:
		await process_frame
	scene.core.start_level(25)
	var tag26: String = String(scene.wind_tag_text())
	scene.core = lo   # 借低线轨迹取结算行（core 为普通 var 可换实例）
	var zt: String = String(scene.settle_zone_text())
	scene.queue_free()
	await process_frame
	_check(tag26 == "逆风 阻力 x1.25 ＋ 下沉气流 40-52 米（俯冲穿越）",
		"C42-6a L26 标签「%s」= 逆风＋单下沉谷" % tag26)
	_check(zt.begins_with("谷出口 ") and zt.contains("米"),
		"C42-6b 低线结算「%s」= 谷出口高度" % zt)

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c42_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
