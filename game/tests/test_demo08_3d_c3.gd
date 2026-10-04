extends SceneTree
## demo-08 3D 阶段 C3（更多机制关卡·回风峡谷 L7）核心不变量（headless，固定 delta=1/60）：
## L7：右侧风 +60px/s²、高门 30m/-6m 横位——先顶风左拐吃门，被风送回中线滑完 70m（折途回风）。
## 三档收益：顶风吃门（+3）> 不顶风漏门 > 摆烂不折不可过。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c3.gd（失败退出码非零）

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


func _mk_l7(folds_n: int, angle: float, hold_t: float) -> Object:
	var c: Object = CoreScript.new()
	c.start_level(6)
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
		c.lateral_input = -1.0 if c.flight_time < hold_t else 0.0
		c.step(DELTA)
		g += 1
	return c


func _run() -> void:
	await process_frame
	_log("demo-08 3D 阶段 C3 回风峡谷测试开始")

	# C3-1 顶风吃门：5 折 30° 顶风 0.8s → 过关 + 高门 +3，末段被风送回（横位回升）
	var good := _mk_l7(5, 30.0, 0.8)
	_check(good.last_pass and good.gate_hit and absf(float(good.flight_distance) - 70.23) < 0.05,
		"C3-1 顶风配方 %.2fm 过关、高门命中（-6m 横位）" % float(good.flight_distance))
	_check(good.coins == 24 and good.gate_coins == 3,
		"C3-1b 收益 24 = 门奖 3 + int(d/10) 7 + 过关奖 14")

	# C3-2 不顶风：同配方被吹右、漏高门（收益少 3），仍可过关
	var lazy := _mk_l7(5, 30.0, 0.0)
	_check(lazy.last_pass and not lazy.gate_hit,
		"C3-2 不顶风 %.2fm 过关但漏高门（横位 %.0f px 被吹右）" % [float(lazy.flight_distance), float(lazy.lateral)])
	_check(lazy.coins == 21, "C3-2b 收益 21 = 结算 7 + 过关奖 14（漏门少 3）")

	# C3-3 摆烂不折：距离不足 70 不可过
	var lazy2 := _mk_l7(0, 30.0, 0.0)
	_check(not lazy2.last_pass and float(lazy2.flight_distance) < 70.0,
		"C3-3 摆烂无折 %.1fm < 70 不可过" % float(lazy2.flight_distance))

	# C3-4 折返还原：顶风 0.8s 与不顶风的末点横位差（风把不顶风的吹得更右）
	_check(float(lazy.lateral) > float(good.lateral),
		"C3-4 回风形：顶风末位 %.0f vs 不顶风 %.0f（风先抗后借）" % [float(good.lateral), float(lazy.lateral)])

	# C3-5 前进/高度与横移零耦合（顶风 vs 不顶风 300 步逐位）
	var t1: Object = CoreScript.new()
	t1.start_level(6)
	var pr1: Rect2 = t1.paper_rect
	for k in 5:
		var mid_y: float = 0.5 - 0.5 * 0.2
		t1.add_fold(pr1.position + pr1.size * Vector2(0.92, mid_y - 0.23),
			pr1.position + pr1.size * Vector2(0.92, mid_y + 0.23))
	t1.finish_folds()
	t1.do_throw(30.0, 1.0)
	var pa: Array = []
	var g5 := 0
	while String(t1.state) == "fly" and g5 < 300:
		t1.lateral_input = 0.0
		t1.step(DELTA)
		pa.append(t1.plane_pos)
		g5 += 1
	var t2: Object = CoreScript.new()
	t2.start_level(6)
	var pr2: Rect2 = t2.paper_rect
	for k in 5:
		var mid_y2: float = 0.5 - 0.5 * 0.2
		t2.add_fold(pr2.position + pr2.size * Vector2(0.92, mid_y2 - 0.23),
			pr2.position + pr2.size * Vector2(0.92, mid_y2 + 0.23))
	t2.finish_folds()
	t2.do_throw(30.0, 1.0)
	var pb: Array = []
	var g6 := 0
	while String(t2.state) == "fly" and g6 < 300:
		t2.lateral_input = -1.0 if t2.flight_time < 0.8 else 0.0
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
	_check(same, "C3-5 侧风/顶风不改变前进与高度轨迹（%d 步逐位一致）" % pa.size())

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c3_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
