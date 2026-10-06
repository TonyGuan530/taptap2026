extends SceneTree
## demo-08 3D 阶段 C45（阶梯①组合关·L29 双谷接力）核心不变量（headless，固定 delta=1/60）：
## 纯既有机制组合（无新字段）：逆风 1.25 × 双下沉谷 30-40m/-50-60m（各 -1400）× 高门 24m/14m + 窗口低门 46m/14m。
## 高度预算课：两谷三站一掷到底。低线（≈28-30°）窗口门 / 高线（≈32-36°）高门，弹道分岔互斥，各 23 币。
## L1-L28 无新字段路径逐位不变。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c45.gd（失败退出码非零）

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
	c.start_level(28)
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
	_log("demo-08 3D 阶段 C45 双谷接力测试开始")

	# C45-1 静态锚：双谷各 -1400（第一谷/第二谷/谷间/终点前）、29 关
	var c1: Object = CoreScript.new()
	c1.start_level(28)
	c1.plane_pos.x = 60.0 + 35.0 * 60.0
	var a1: float = c1.updraft_accel()
	c1.plane_pos.x = 60.0 + 45.0 * 60.0
	var agap: float = c1.updraft_accel()
	c1.plane_pos.x = 60.0 + 55.0 * 60.0
	var a2: float = c1.updraft_accel()
	c1.plane_pos.x = 60.0 + 61.0 * 60.0
	var aout: float = c1.updraft_accel()
	_check(a1 == -1400.0 and agap == 0.0 and a2 == -1400.0 and aout == 0.0
		and int(c1.LEVELS.size()) == 39,
		"C45-1 静态锚：谷1 -1400 / 窗口 0 / 谷2 -1400 / 谷后 0，29 关")

	# C45-2 低线：4 折 v=0.2 30° → 过关吃窗口低门，23 = 3 + 6 + 14
	var lo: Object = _mk_and_fly(4, 0.2, 30.0)
	_check(lo.last_pass and lo.low_gate_hit and not lo.gate_hit,
		"C45-2 低线过关吃窗口低门（%.1fm）" % lo.flight_distance)
	_check(lo.coins == 23 and lo.gate_coins == 3,
		"C45-2b 收益 23 = 门奖 3 + int(d/10) 6 + 过关奖 14")

	# C45-3 高线：4 折 v=0.2 34° → 过关吃高门漏窗口门（弹道分岔互斥）
	var hi: Object = _mk_and_fly(4, 0.2, 34.0)
	_check(hi.last_pass and hi.gate_hit and not hi.low_gate_hit,
		"C45-3 高线过关吃高门（%.1fm）" % hi.flight_distance)

	# C45-4 摆烂对照：弱抛判负
	var lazy: Object = _mk_and_fly(4, 0.2, 45.0, 0.3)
	_check(not lazy.last_pass, "C45-4 摆烂弱抛判负（%.1fm）" % lazy.flight_distance)

	# C45-5 标签：双谷依次列出；结算出口高度行（双谷取第二谷出口）
	var scene: Node = load("res://demo08_3d.tscn").instantiate()
	root.add_child(scene)
	for k in 3:
		await process_frame
	scene.core.start_level(28)
	var tag29: String = String(scene.wind_tag_text())
	scene.core = lo
	var zt: String = String(scene.settle_zone_text())
	scene.queue_free()
	await process_frame
	_check(tag29 == "逆风 阻力 x1.25 ＋ 下沉气流 30-40 米（俯冲穿越） ＋ 下沉气流 50-60 米（俯冲穿越）",
		"C45-5a L29 标签「%s」= 逆风＋双谷依次列出" % tag29)
	_check(zt.begins_with("谷出口 ") and zt.contains("米"),
		"C45-5b 低线结算「%s」= 第二谷出口高度" % zt)

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c45_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
