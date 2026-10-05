extends SceneTree
## demo-08 3D 阶段 C31（阶梯①组合关·L19 逆风S形摆门）核心不变量（headless，固定 delta=1/60）：
## 纯既有机制组合（无新字段）：wind="head"（阻力×1.25）× side_wind=-60 双段切变（30m/55m 翻转）
## × 摆动门 +240±300/4s。L1-L18 无新字段路径逐位不变。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c31.gd（失败退出码非零）

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


func _mk_l19(folds_v: Array, angle: float, use_pos_hold: bool) -> Object:
	var c: Object = CoreScript.new()
	c.start_level(18)
	if folds_v.size() > 0:
		var pr: Rect2 = c.paper_rect
		for v in folds_v:
			var mid_y: float = 0.5 - 0.5 * float(v)
			c.add_fold(pr.position + pr.size * Vector2(0.92, mid_y - 0.23),
				pr.position + pr.size * Vector2(0.92, mid_y + 0.23))
	c.finish_folds()
	c.do_throw(angle, 1.0)
	var g := 0
	while String(c.state) == "fly" and g < MAX_STEPS:
		var in_pos_window: bool = c.plane_pos.x >= 60.0 + 30.2 * 60.0 and c.plane_pos.x < 60.0 + 54.8 * 60.0
		c.lateral_input = 1.0 if (use_pos_hold and in_pos_window) else 0.0
		c.step(DELTA)
		g += 1
	return c


func _run() -> void:
	await process_frame
	_log("demo-08 3D 阶段 C31 逆风S形摆门测试开始")

	# C31-1 三段符号（C13 翻转作用于正交侧风）：20/40/60m 处有效侧风 -60/+60/-60
	var c1: Object = CoreScript.new()
	c1.start_level(18)
	var segs := {}
	for xm in [20.0, 40.0, 60.0]:
		c1.plane_pos.x = 60.0 + xm * 60.0
		segs[xm] = float(c1.side_wind_accel()) * float(c1.shear_sign_flip())
	_check(String(c1.wind_mode()) == "head" and segs[20.0] == -60.0 and segs[40.0] == 60.0 and segs[60.0] == -60.0,
		"C31-1 三段有效侧风：20m=%s 40m=%s 60m=%s（-/+/-）" % [str(segs[20.0]), str(segs[40.0]), str(segs[60.0])])

	# C31-2 摆门公式：t=1.0 右极 +540；t=3.0 左极 -60（窗口 [-60,540]）
	var c2: Object = CoreScript.new()
	c2.start_level(18)
	_check(absf(float(c2.gate_side_at(1.0)) - 540.0) < 1e-6 and absf(float(c2.gate_side_at(3.0)) + 60.0) < 1e-6,
		"C31-2 门摆公式：右极 540 / 左极 -60（窗口 [-60,540]）")

	# C31-3 位置窗顶风配方：过关 + 高门 + 收益 24 = 3 + 7 + 14
	var good := _mk_l19([0.2, 0.2, 0.2, 0.2, 0.2], 30.0, true)
	_check(good.last_pass and good.gate_hit and absf(float(good.flight_distance) - 70.27) < 0.05,
		"C31-3 位置窗顶风 %.2fm 过关、高门命中（末位横位 %.0f px）" % [
			float(good.flight_distance), float(good.lateral)])
	_check(good.coins == 24 and good.gate_coins == 3, "C31-3b 收益 24 = 门奖 3 + int(d/10) 7 + 过关奖 14")

	# C31-4 零耦合：顶风 vs 无舵 前进/高度 300 步逐位一致（侧风不碰纵向积分）
	var t1: Object = CoreScript.new()
	t1.start_level(18)
	var pr1: Rect2 = t1.paper_rect
	for k in 5:
		var mid_y1: float = 0.5 - 0.5 * 0.2
		t1.add_fold(pr1.position + pr1.size * Vector2(0.92, mid_y1 - 0.23),
			pr1.position + pr1.size * Vector2(0.92, mid_y1 + 0.23))
	t1.finish_folds()
	t1.do_throw(30.0, 1.0)
	var pa: Array = []
	var g5 := 0
	while String(t1.state) == "fly" and g5 < 300:
		var in_win: bool = t1.plane_pos.x >= 60.0 + 30.2 * 60.0 and t1.plane_pos.x < 60.0 + 54.8 * 60.0
		t1.lateral_input = 1.0 if in_win else 0.0
		t1.step(DELTA)
		pa.append(t1.plane_pos)
		g5 += 1
	var t2: Object = CoreScript.new()
	t2.start_level(18)
	var pr2: Rect2 = t2.paper_rect
	for k in 5:
		t2.add_fold(pr2.position + pr2.size * Vector2(0.92, 0.5 - 0.5 * 0.2 - 0.23),
			pr2.position + pr2.size * Vector2(0.92, 0.5 - 0.5 * 0.2 + 0.23))
	t2.finish_folds()
	t2.do_throw(30.0, 1.0)
	var pb: Array = []
	var g6 := 0
	while String(t2.state) == "fly" and g6 < 300:
		t2.step(DELTA)
		pb.append(t2.plane_pos)
		g6 += 1
	var same := pa.size() == pb.size()
	if same:
		for i in pa.size():
			var va: Vector2 = pa[i]
			var vb: Vector2 = pb[i]
			if va.distance_to(vb) > 1e-9:
				same = false
				break
	_check(same, "C31-5 侧风/顶风不改变前进与高度轨迹（%d 步逐位一致）" % pa.size())

	# C31-6 摆烂不可过：无折 < 70
	var lazy := _mk_l19([], 30.0, true)
	_check(not lazy.last_pass and float(lazy.flight_distance) < 70.0,
		"C31-6 摆烂无折 %.1fm < 70 不可过" % float(lazy.flight_distance))

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c31_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
