extends SceneTree
## demo-08 3D 阶段 C6（阶梯①组合关·L9 斜风峡谷）核心不变量（headless，固定 delta=1/60）：
## 规则变化 C6：LEVELS 可选正交字段 side_wind（px/s² 带符号）——与 forward 风（head/tail/none）叠加；
## L1-L8 无该字段路径逐位不变。L9：逆风阻力 ×1.25 与左漂 -60px/s² 同时生效。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c6.gd（失败退出码非零）

const CoreScript := preload("res://demo08_3d/flight_core.gd")
const DELTA := 1.0 / 60.0
const MAX_STEPS := 1800

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


func _mk_l9(folds_n: int, angle: float, hold_t: float) -> Object:
	var c: Object = CoreScript.new()
	c.start_level(8)
	if folds_n > 0:
		var pr: Rect2 = c.paper_rect
		for k in folds_n:
			var mid_y: float = 0.5 - 0.5 * 0.2
			c.add_fold(pr.position + pr.size * Vector2(0.92, mid_y - 0.23),
				pr.position + pr.size * Vector2(0.92, mid_y + 0.23))
	c.finish_folds()
	c.do_throw(angle, 1.0)
	var g := 0
	while String(c.state) == "fly" and g < MAX_STEPS:
		c.lateral_input = 1.0 if c.flight_time < hold_t else 0.0
		c.step(DELTA)
		g += 1
	return c


func _run() -> void:
	await process_frame
	_log("demo-08 3D 阶段 C6 斜风峡谷测试开始")

	# C6-1 正交生效：wind_mode=head（逆风在）且 side_wind_accel=-60（侧风在）
	var c1: Object = CoreScript.new()
	c1.start_level(8)
	_check(String(c1.wind_mode()) == "head" and absf(float(c1.side_wind_accel()) - (-60.0)) < 1e-9,
		"C6-1 L9 双风配置：逆风 + 侧风 -60 正交并存")

	# C6-2 不顶风被吹左：无舵横向漂移为负
	var drift := _mk_l9(5, 30.0, 0.0)
	_check(float(drift.lateral) <= -150.0,
		"C6-2 无舵被吹离中线 %.0f px（左漂生效）" % float(drift.lateral))

	# C6-3 合理折法+顶右风：过关 + 高门 + 收益 20 = 3 + 5 + 12
	var good := _mk_l9(5, 30.0, 0.8)
	_check(good.last_pass and good.gate_hit and absf(float(good.flight_distance) - 50.18) < 0.05,
		"C6-3 顶风配方 %.2fm 过关、高门命中（横位 %.0f px）" % [float(good.flight_distance), float(good.lateral)])
	_check(good.coins == 20 and good.gate_coins == 3, "C6-3b 收益 20 = 门奖 3 + int(d/10) 5 + 过关奖 12")

	# C6-4 摆烂不可过：无折 < 50
	var lazy := _mk_l9(0, 30.0, 0.0)
	_check(not lazy.last_pass and float(lazy.flight_distance) < 50.0,
		"C6-4 摆烂无折 %.1fm < 50 不可过（逆风+侧风双 fighting）" % float(lazy.flight_distance))

	# C6-5 逆风阻力确实在：L9 同配方距离 < L6（同 4 折 30° 满力，L6 顺风系无 head drag 且距离 60+）
	var c5ref: Object = CoreScript.new()
	c5ref.start_level(5)
	var pr5: Rect2 = c5ref.paper_rect
	for k in 5:
		var mid_y5: float = 0.5 - 0.5 * 0.2
		c5ref.add_fold(pr5.position + pr5.size * Vector2(0.92, mid_y5 - 0.23),
			pr5.position + pr5.size * Vector2(0.92, mid_y5 + 0.23))
	c5ref.finish_folds()
	c5ref.do_throw(30.0, 1.0)
	var g5 := 0
	while String(c5ref.state) == "fly" and g5 < MAX_STEPS:
		c5ref.lateral_input = 1.0 if c5ref.flight_time < 0.8 else 0.0
		c5ref.step(DELTA)
		g5 += 1
	_check(float(good.flight_distance) < float(c5ref.flight_distance) - 5.0,
		"C6-5 逆风惩罚可测：L9 %.1fm < L6 同配方 %.1fm（拖曳×1.25）" % [
			float(good.flight_distance), float(c5ref.flight_distance)])

	# C6-6 前进/高度与横移零耦合（顶风 vs 无舵 240 步逐位）
	var t1: Object = CoreScript.new()
	t1.start_level(8)
	var pr1: Rect2 = t1.paper_rect
	for k in 5:
		var mid_y1: float = 0.5 - 0.5 * 0.2
		t1.add_fold(pr1.position + pr1.size * Vector2(0.92, mid_y1 - 0.23),
			pr1.position + pr1.size * Vector2(0.92, mid_y1 + 0.23))
	t1.finish_folds()
	t1.do_throw(30.0, 1.0)
	var pa: Array = []
	var g6 := 0
	while String(t1.state) == "fly" and g6 < 240:
		t1.step(DELTA)
		pa.append(t1.plane_pos)
		g6 += 1
	var t2: Object = CoreScript.new()
	t2.start_level(8)
	var pr2: Rect2 = t2.paper_rect
	for k in 5:
		var mid_y2: float = 0.5 - 0.5 * 0.2
		t2.add_fold(pr2.position + pr2.size * Vector2(0.92, mid_y2 - 0.23),
			pr2.position + pr2.size * Vector2(0.92, mid_y2 + 0.23))
	t2.finish_folds()
	t2.do_throw(30.0, 1.0)
	var pb: Array = []
	var g7 := 0
	t2.lateral_input = 1.0
	while String(t2.state) == "fly" and g7 < 240:
		t2.step(DELTA)
		pb.append(t2.plane_pos)
		g7 += 1
	var same := pa.size() == pb.size()
	if same:
		for i in pa.size():
			var va: Vector2 = pa[i]
			var vb: Vector2 = pb[i]
			if va.distance_to(vb) > 1e-9:
				same = false
				break
	_check(same, "C6-6 侧风/顶风不改变前进与高度轨迹（%d 步逐位一致）" % pa.size())

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c6_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
