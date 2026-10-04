extends SceneTree
## demo-08 3D 阶段 C2（更多机制关卡·侧风走廊 L6）核心不变量（headless，固定 delta=1/60）：
## 规则变化 C2：新风型 wind="side"（恒定横向加速度 LAT_WIND=60px/s²，方向 wind_side）；
## L6 配置追加（五关原始配置未动，LEVELS 扩展为内容变化）。
## 双用例：合理折法+顶风 可过关吃门；摆烂不折不可过、不顶风被吹离中线。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c2.gd（失败退出码非零）

const CoreScript := preload("res://demo08_3d/flight_core.gd")
const DELTA := 1.0 / 60.0
const MAX_STEPS := 1500

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


func _mk_l6(folds_v: Array, angle: float, hold_t: float) -> Object:
	var c: Object = CoreScript.new()
	c.start_level(5)
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
		c.lateral_input = 1.0 if c.flight_time < hold_t else 0.0
		c.step(DELTA)
		g += 1
	return c


func _run() -> void:
	await process_frame
	_log("demo-08 3D 阶段 C2 侧风走廊测试开始")

	# C2-1 侧风力学：无折直扔不顶风 → 被吹向左、贴左界
	var blown := _mk_l6([], 30.0, 0.0)
	_check(float(blown.lateral) <= -200.0,
		"C2-1 无折不顶风被吹离中线 %.0f px（侧风 %.0f px/s² 生效）" % [float(blown.lateral), float(blown.LAT_WIND)])
	_check(not blown.last_pass and float(blown.flight_distance) < 60.0,
		"C2-1b 摆烂不折 %.1fm < 60 不可过" % float(blown.flight_distance))

	# C2-2 反舵力学：同起点按住 D，2 秒时横向位置显著靠右（顶风有效）
	var c2a: Object = CoreScript.new()
	c2a.start_level(5)
	c2a.finish_folds()
	c2a.do_throw(30.0, 1.0)
	var g2 := 0
	while String(c2a.state) == "fly" and g2 < 120:
		c2a.step(DELTA)
		g2 += 1
	var lat_novinput: float = float(c2a.lateral)
	var c2b: Object = CoreScript.new()
	c2b.start_level(5)
	c2b.finish_folds()
	c2b.do_throw(30.0, 1.0)
	var g3 := 0
	while String(c2b.state) == "fly" and g3 < 120:
		c2b.lateral_input = 1.0
		c2b.step(DELTA)
		g3 += 1
	var lat_hold: float = float(c2b.lateral)
	_check(lat_hold - lat_novinput > 300.0,
		"C2-2 顶风 2s 横向位置差 %.0f px（无舵 %.0f vs 顶风 %.0f）" % [lat_hold - lat_novinput, lat_novinput, lat_hold])

	# C2-3 合理折法过关吃门（搜索配方：4 折 v=0.2、30°、顶风 0.4s）
	var good := _mk_l6([0.2, 0.2, 0.2, 0.2], 30.0, 0.4)
	_check(good.last_pass and good.gate_hit and absf(float(good.lateral) - (-44.85)) < 1.0,
		"C2-3 顶风配方 %.1fm 过关、高门命中（横位 %.0f px 近中线）" % [float(good.flight_distance), float(good.lateral)])
	_check(good.coins == 21 and good.gate_coins == 3,
		"C2-3b 收益 21 = 门奖 3 + int(d/10) 6 + 过关奖 12")

	# C2-4 前进/高度不受横移与侧风影响：顶风 vs 无舵前进轨迹逐位一致
	var t1: Object = CoreScript.new()
	t1.start_level(5)
	var pr1: Rect2 = t1.paper_rect
	for v in [0.2, 0.2, 0.2, 0.2]:
		var mid_y: float = 0.5 - 0.5 * float(v)
		t1.add_fold(pr1.position + pr1.size * Vector2(0.92, mid_y - 0.23),
			pr1.position + pr1.size * Vector2(0.92, mid_y + 0.23))
	t1.finish_folds()
	t1.do_throw(30.0, 1.0)
	var pa: Array = []
	var g4 := 0
	while String(t1.state) == "fly" and g4 < 200:
		t1.lateral_input = 0.0
		t1.step(DELTA)
		pa.append(t1.plane_pos)
		g4 += 1
	var t2: Object = CoreScript.new()
	t2.start_level(5)
	var pr2: Rect2 = t2.paper_rect
	for v in [0.2, 0.2, 0.2, 0.2]:
		var mid_y2: float = 0.5 - 0.5 * float(v)
		t2.add_fold(pr2.position + pr2.size * Vector2(0.92, mid_y2 - 0.23),
			pr2.position + pr2.size * Vector2(0.92, mid_y2 + 0.23))
	t2.finish_folds()
	t2.do_throw(30.0, 1.0)
	var pb: Array = []
	var g5 := 0
	while String(t2.state) == "fly" and g5 < 200:
		t2.lateral_input = 1.0
		t2.step(DELTA)
		pb.append(t2.plane_pos)
		g5 += 1
	var same := pa.size() == pb.size()
	if same:
		for i in pa.size():
			var va: Vector2 = pa[i]
			var vb: Vector2 = pb[i]
			if va.distance_to(vb) > 1e-9:
				same = false
				break
	_check(same, "C2-4 侧风/顶风不改变前进与高度轨迹（%d 步逐位一致）" % pa.size())

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c2_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
