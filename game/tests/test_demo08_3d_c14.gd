extends SceneTree
## demo-08 3D 阶段 C14（阶梯①组合关·L15 三段侧风）核心不变量（headless，固定 delta=1/60）：
## C13 机制（切变面翻转正交侧风）的首次实战应用：wind=head + side_wind=+60 →(30m)→ -60 →(50m)→ +60。
## 高门 42m/-4m 横位在左拽段——全程顶左风（A）即"顺着风走"的可解释配方。L1-L14 路径逐位不变。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c14.gd（失败退出码非零）

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


func _mk_l15(folds_v: Array, angle: float, policy: String) -> Dictionary:
	var c: Object = CoreScript.new()
	c.start_level(14)
	if folds_v.size() > 0:
		var pr: Rect2 = c.paper_rect
		for v in folds_v:
			var mid_y: float = 0.5 - 0.5 * float(v)
			c.add_fold(pr.position + pr.size * Vector2(0.92, mid_y - 0.23),
				pr.position + pr.size * Vector2(0.92, mid_y + 0.23))
	c.finish_folds()
	c.do_throw(angle, 1.0)
	var g := 0
	var lat42 := 99999.0
	while String(c.state) == "fly" and g < MAX_STEPS:
		var input := 0.0
		match policy:
			"holdA":
				input = -1.0
			"none":
				input = 0.0
		c.lateral_input = input
		var px_before: float = c.plane_pos.x
		c.step(DELTA)
		if lat42 > 9000.0 and px_before < 60.0 + 42.0 * 60.0 and c.plane_pos.x >= 60.0 + 42.0 * 60.0:
			lat42 = float(c.lateral)
		g += 1
	return {c = c, d = float(c.flight_distance), high = c.gate_hit, ok = c.last_pass,
		lat = float(c.lateral), lat42 = lat42, coins = int(c.coins)}


func _run() -> void:
	await process_frame
	_log("demo-08 3D 阶段 C14 三段侧风测试开始")

	# C14-1 三段配置与有效侧风：wind=head 关卡用 side_wind_accel × shear_sign_flip（C13 组合语义）
	var c1: Object = CoreScript.new()
	c1.start_level(14)
	var segs := {}
	for xm in [20.0, 40.0, 60.0]:
		c1.plane_pos.x = 60.0 + xm * 60.0
		segs[xm] = float(c1.side_wind_accel()) * float(c1.shear_sign_flip())
	_check(String(c1.wind_mode()) == "head" and absf(float(c1.side_wind_accel()) - 60.0) < 1e-9
		and segs[20.0] == 60.0 and segs[40.0] == -60.0 and segs[60.0] == 60.0,
		"C14-1 三段配置与有效侧风：20m=%s 40m=%s 60m=%s（+/-/+）" % [str(segs[20.0]), str(segs[40.0]), str(segs[60.0])])

	# C14-2 全程顶左风（顺势）：过关 + 高门 + 收益 23 = 3 + 6 + 14
	var good: Dictionary = _mk_l15([0.2, 0.2, 0.2, 0.2, 0.2, 0.2], 30.0, "holdA")
	_check(good.ok and good.high and absf(good.d - 65.3) < 0.05,
		"C14-2 全程顶左风 %.2fm 过关、高门命中（横位 %.0f px ∈ 窗口 [-540,60]）" % [
			good.d, good.lat])
	_check(good.coins == 23 and int(good.c.gate_coins) == 3, "C14-2b 收益 23 = 门奖 3 + int(d/10) 6 + 过关奖 14")

	# C14-3 不顶风漏门：同配方能过关但 42m 横位在窗外（收益少 3，可解释）
	var lazy: Dictionary = _mk_l15([0.2, 0.2, 0.2, 0.2, 0.2, 0.2], 30.0, "none")
	_check(lazy.ok and not lazy.high and lazy.coins == 20,
		"C14-3 不顶风 %.2fm 过关漏门（42m 横位 %.0f px 窗外，收益 20）" % [
			lazy.d, lazy.lat42])

	# C14-4 摆烂不可过：无折 < 65
	var none2: Dictionary = _mk_l15([], 30.0, "none")
	_check(not none2.ok and none2.d < 65.0,
		"C14-4 摆烂无折 %.1fm < 65 不可过" % none2.d)

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c14_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
