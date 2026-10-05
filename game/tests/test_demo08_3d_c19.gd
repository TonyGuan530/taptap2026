extends SceneTree
## demo-08 3D 阶段 C19（阶梯②低空摆动门·L18）核心不变量（headless，固定 delta=1/60）：
## 规则变化 C19：LEVELS 可选 low_gate_swing/low_gate_period（低空门独立摆动，0=静止）；
## low_gate_side_at(t) 与判定共用。L1-L17 低空门无摆动字段路径逐位不变。
## L18：高门固定 40m（+0m），低门 44m 横位 0±300/3s 摆动——一掷二选一。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c19.gd（失败退出码非零）

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


## 合成穿越：L18 低门 44m（2700px），横位 lat、飞行时间 t（决定门摆相位）
func _cross_low(lat: float, t: float) -> Object:
	var c: Object = CoreScript.new()
	c.start_level(17)
	var pr: Rect2 = c.paper_rect
	for k in 5:
		var mid_y: float = 0.5 - 0.5 * 0.2
		c.add_fold(pr.position + pr.size * Vector2(0.92, mid_y - 0.23),
			pr.position + pr.size * Vector2(0.92, mid_y + 0.23))
	c.finish_folds()
	c.do_throw(30.0, 1.0)
	c.plane_pos = Vector2(60.0 + 43.5 * 60.0, 460.0 - 8.0 * 60.0)  # 低门 44m 前，8m 高（≤10m 低门窗）
	c.velocity = Vector2(600.0, 0.0)
	c.lateral = lat
	c.flight_time = t
	for k in 6:
		var e: String = c.step(DELTA)
		if e == "finish" or e == "ground" or e == "timeout":
			break
		if c.plane_pos.x >= 60.0 + 44.2 * 60.0:
			break
	return c


func _run() -> void:
	await process_frame
	_log("demo-08 3D 阶段 C19 低空摆门测试开始")

	# C19-1 低门摆动公式：side 0 ± 300，周期 3s——t=0.75 右极 +300，t=2.25 左极 -300
	var c1: Object = CoreScript.new()
	c1.start_level(17)
	_check(absf(float(c1.low_gate_side_at(0.75)) - 300.0) < 1e-6
		and absf(float(c1.low_gate_side_at(2.25)) + 300.0) < 1e-6,
		"C19-1 低门摆动公式：右极 +300 / 左极 -300")

	# C19-2 相位依赖合成穿越：同横位 +200，门右相（-300+300×sin… t=0.75 门位 +300）距离 100 命中；
	# t=2.25 门位 -300 距离 500 错过
	var hit := _cross_low(200.0, 0.75)
	var miss := _cross_low(200.0, 2.25)
	_check(hit.low_gate_hit and not miss.low_gate_hit and int(hit.coins) == 3 and int(miss.coins) == 0,
		"C19-2 同横位不同相位：右相命中 +3 / 左相错过 0（低门摆动生效，门奖即时入账）")

	# C19-3 静止锚：L2 低门无摆动字段 → low_gate_side_at 恒 0
	var c3: Object = CoreScript.new()
	c3.start_level(1)
	var static_ok := true
	for t in [0.0, 0.75, 1.5, 2.25]:
		if absf(float(c3.low_gate_side_at(t))) > 1e-12:
			static_ok = false
	_check(static_ok, "C19-3 静止关卡低门横位恒 0（低门摆动字段隔离）")

	# C19-4 互斥：先吃低门后过高门（高门不再付钱）
	var c4 := _cross_low(200.0, 0.75)
	c4.gate_hit = false  # 清高门标记后单独过高门平面（合成）
	c4.plane_pos = Vector2(60.0 + 47.5 * 60.0, 460.0 - 13.0 * 60.0)
	c4.velocity = Vector2(600.0, 0.0)
	var coins_before: int = int(c4.coins)
	for k in 6:
		var e4: String = c4.step(DELTA)
		if e4 == "finish" or e4 == "ground" or e4 == "timeout":
			break
		if c4.plane_pos.x >= 60.0 + 48.5 * 60.0:
			break
	_check(not c4.gate_hit and int(c4.coins) == coins_before,
		"C19-4 低门已领 → 高门不再付钱（互斥保持）")

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c19_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
