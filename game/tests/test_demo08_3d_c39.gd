extends SceneTree
## demo-08 3D 阶段 C39（阶梯②新机制·L25 热气流救援）核心不变量（headless，固定 delta=1/60）：
## 规则变化扩展（C43）：第二气流区带 wind_up2_x/len/wind_up（沉后托波形，双带命中取和）。
## L25 = 逆风 80m × 下沉谷 40-52m/-2500 × 热流 54-70m/+3000 × 高门 72m/18m——热气流是救援本身：
## 设计探针记录（wind_up2=0 对照）：40° 直接坠地（h72 无值）、45° 3.1m 过 72m 且滑程不足判负——无热流不可过。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c39.gd（失败退出码非零）

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
	_log("demo-08 3D 阶段 C39 热气流救援测试开始")

	# C39-1 双区带分段：L25 谷内 -2500 / 热流内 +3000 / 区外 0；L24 单带不受影响；25 关
	var c1: Object = CoreScript.new()
	c1.start_level(24)
	c1.plane_pos.x = 60.0 + 45.0 * 60.0
	var a_sink: float = c1.updraft_accel()
	c1.plane_pos.x = 60.0 + 60.0 * 60.0
	var a_therm: float = c1.updraft_accel()
	c1.plane_pos.x = 60.0 + 74.0 * 60.0
	var a_out: float = c1.updraft_accel()
	c1.start_level(23)
	c1.plane_pos.x = 60.0 + 55.0 * 60.0
	var a_l24: float = c1.updraft_accel()
	_check(a_sink == -2500.0 and a_therm == 3000.0 and a_out == 0.0
		and a_l24 == -1600.0 and int(c1.LEVELS.size()) == 41,
		"C39-1 双区带分段：谷 -2500 / 热流 +3000 / 区外 0 / L24 单带 -1600，40 关")

	# C39-2 配方：4 折 v=0.2 40° → 过关吃高门，收益 25 = 3 + 8 + 14
	var good: Object = _mk_and_fly(24, 4, 0.2, 40.0, 1.0)
	_check(good.last_pass and good.gate_hit,
		"C39-2 配方过关吃高门（%.1fm）" % good.flight_distance)
	_check(good.coins == 25 and good.gate_coins == 3,
		"C39-2b 收益 25 = 门奖 3 + int(d/10) 8 + 过关奖 14")

	# C39-3 摆烂对照：弱抛 0.3 力 → 滑不到谷就落地判负（气流区不改结算优先级）
	var lazy: Object = _mk_and_fly(24, 4, 0.2, 45.0, 0.3)
	_check(not lazy.last_pass,
		"C39-3 摆烂弱抛判负（%.1fm < 80m）" % lazy.flight_distance)

	# C39-4 风标签：逆风＋双区带依次列出；L24 标签回归
	var scene: Node = load("res://demo08_3d.tscn").instantiate()
	root.add_child(scene)
	for k in 3:
		await process_frame
	scene.core.start_level(24)
	var tag25: String = String(scene.wind_tag_text())
	scene.core.start_level(23)
	var tag24: String = String(scene.wind_tag_text())
	scene.queue_free()
	await process_frame
	_check(tag25 == "逆风 阻力 x1.25 ＋ 下沉气流 40-52 米（俯冲穿越） ＋ 上升气流 54-70 米（乘流爬升）",
		"C39-4a L25 标签「%s」= 逆风＋双区带" % tag25)
	_check(tag24 == "逆风 阻力 x1.25 ＋ 下沉气流 50-70 米（俯冲穿越）",
		"C39-4b L24 标签不变回归「%s」" % tag24)

	# C39-5 L1 静止锚：无任何气流区
	var c5: Object = CoreScript.new()
	c5.start_level(0)
	c5.plane_pos.x = 60.0 + 55.0 * 60.0
	_check(float(c5.updraft_accel()) == 0.0,
		"C39-5 L1 静止锚：无气流区")

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c39_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
