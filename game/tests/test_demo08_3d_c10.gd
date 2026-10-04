extends SceneTree
## demo-08 3D 阶段 C10（阶梯②新门类型·摆动之门 L11）核心不变量（headless，固定 delta=1/60）：
## 规则变化 C10：LEVELS 可选 gate_swing（振幅 px）/gate_period（周期 s）——门横位随飞行时间正弦摆动；
## 判定与场景渲染共用 gate_side_at(t)。L1-L10 无该字段，门横位静止、路径逐位不变。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c10.gd（失败退出码非零）

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


## 合成穿越：L11 高门 45m（2700px），横位 lat、飞行时间 t（决定门瞬时相位）
func _cross_at(lat: float, t: float) -> Object:
	var c: Object = CoreScript.new()
	c.start_level(10)
	var pr: Rect2 = c.paper_rect
	for k in 5:
		var mid_y: float = 0.5 - 0.5 * 0.2
		c.add_fold(pr.position + pr.size * Vector2(0.92, mid_y - 0.23),
			pr.position + pr.size * Vector2(0.92, mid_y + 0.23))
	c.finish_folds()
	c.do_throw(35.0, 1.0)
	c.plane_pos = Vector2(60.0 + 44.5 * 60.0, 460.0 - 13.0 * 60.0)  # 高门 45m 前，13m 高
	c.velocity = Vector2(600.0, 0.0)
	c.lateral = lat
	c.flight_time = t
	for k in 6:
		var e: String = c.step(DELTA)
		if e == "finish" or e == "ground" or e == "timeout":
			break
		if c.plane_pos.x >= 60.0 + 45.2 * 60.0:
			break
	return c


func _run() -> void:
	await process_frame
	_log("demo-08 3D 阶段 C10 摆动之门测试开始")

	# C10-1 gate_side_at 确定性：周期 3s，四分之一相位 = ±420
	var c0: Object = CoreScript.new()
	c0.start_level(10)
	var v0: float = float(c0.gate_side_at(0.0))
	var vq: float = float(c0.gate_side_at(0.75))
	var vh: float = float(c0.gate_side_at(1.5))
	var v3q: float = float(c0.gate_side_at(2.25))
	_check(absf(v0) < 1e-9 and absf(vq - 420.0) < 1e-6 and absf(vh) < 1e-6 and absf(v3q + 420.0) < 1e-6,
		"C10-1 门横位公式：0/±420（振幅 420 周期 3s）")

	# C10-2 相位依赖：同横位 +399，门在右相（+405）命中；门在左相（-399.5）错过
	var hit := _cross_at(399.0, 0.7)
	var miss := _cross_at(399.0, 2.2)
	_check(hit.gate_hit and not miss.gate_hit,
		"C10-2 同横位不同相位：右相命中 / 左相错过（摆动生效）")

	# C10-3 合理折法（无舵 35°，横位 0 恰逢门回中相位）：过关 + 高门 + 收益 20 = 3 + 5 + 12
	var good := _mk_l11(5, 35.0, 0.0)
	_check(good.last_pass and good.gate_hit and absf(float(good.flight_distance) - 55.09) < 0.05,
		"C10-3 无舵配方 %.2fm 过关、高门命中（横位 %.0f px 回中相位）" % [float(good.flight_distance), float(good.lateral)])
	_check(good.coins == 20 and good.gate_coins == 3, "C10-3b 收益 20 = 门奖 3 + int(d/10) 5 + 过关奖 12")

	# C10-4 摆烂不可过：无折 < 55
	var lazy := _mk_l11(0, 30.0, 0.0)
	_check(not lazy.last_pass and float(lazy.flight_distance) < 55.0,
		"C10-4 摆烂无折 %.1fm < 55 不可过" % float(lazy.flight_distance))

	# C10-5 静止关卡回归锚：L2 无摆动字段 → gate_side_at 恒 0
	var c5: Object = CoreScript.new()
	c5.start_level(1)
	var static_ok := true
	for t in [0.0, 0.75, 1.5, 2.25]:
		if absf(float(c5.gate_side_at(t))) > 1e-12:
			static_ok = false
	_check(static_ok, "C10-5 静止关卡门横位恒 0（摆动字段隔离）")

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c10_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)


func _mk_l11(folds_n: int, angle: float, hold_t: float) -> Object:
	var c: Object = CoreScript.new()
	c.start_level(10)
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
