extends SceneTree
## demo-08 3D 阶段 C63（大师篇·L39 俯冲侧峡）核心不变量（headless，固定 delta=1/60）：
## 纯既有机制组合（无新字段）：逆风 × 左推侧风 -60 × 低门 52m/top18/+240 横位 × 俯冲输入。
## 双操作课：不俯冲自然滑翔 21m 过顶漏门；俯冲+D 窗压到 13.5-16.7m 穿门 24 币。
## 配方 3×0.35@27° dive=1.2s + D 0.4-1.2s。L1-L38 逐位不变。39 关。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c63.gd（失败退出码非零）

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


func _mk_and_fly(n: int, v: float, ang: float, dive_at: float, d0: float, d1: float, pw: float = 1.0) -> Object:
	var c: Object = CoreScript.new()
	c.start_level(38)
	var pr: Rect2 = c.paper_rect
	for k in n:
		var mid_y: float = 0.5 - 0.5 * v
		c.add_fold(pr.position + pr.size * Vector2(0.92, mid_y - 0.23),
			pr.position + pr.size * Vector2(0.92, mid_y + 0.23))
	c.finish_folds()
	c.do_throw(ang, pw)
	var g := 0
	while String(c.state) == "fly" and g < MAX_STEPS:
		c.dive_input = dive_at > 0.0 and c.flight_time >= dive_at
		c.lateral_input = 1.0 if (c.flight_time >= d0 and c.flight_time < d1) else 0.0
		c.step(DELTA)
		g += 1
	return c


func _run() -> void:
	await process_frame
	_log("demo-08 3D 阶段 C63 俯冲侧峡测试开始")

	# C63-1 静态锚：低门 52m/top18/+240、左推侧风 -60、39 关
	var c1: Object = CoreScript.new()
	c1.start_level(38)
	_check(absf(float(c1.LEVELS[38].low_gate_x) - 52.0) < 1e-6
		and absf(float(c1.LEVELS[38].low_gate_top) - 18.0) < 1e-6
		and absf(float(c1.LEVELS[38].low_gate_side) - 240.0) < 1e-6
		and float(c1.side_wind_accel()) == -60.0 and int(c1.LEVELS.size()) == 39,
		"C63-1 静态锚：低门 52m/top18/+240 / 侧风 -60 / 39 关")

	# C63-2 双操作配方：3 折 v=0.35 27°、dive=1.2s + D 0.4-1.2s → 过关穿低门，24 = 3 + 7 + 14
	var good: Object = _mk_and_fly(3, 0.35, 27.0, 1.2, 0.4, 1.2)
	_check(good.last_pass and good.low_gate_hit,
		"C63-2 双操作配方过关穿低门（%.1fm）" % good.flight_distance)
	_check(good.coins == 24,
		"C63-2b 收益 24 = 门奖 3 + int(d/10) 7 + 过关奖 14")

	# C63-3 只俯冲不顶风：D 缺省（被风左带出带 lat -474）→ 漏门 21 币
	var dive_only: Object = _mk_and_fly(3, 0.35, 27.0, 1.2, -1.0, -1.0)
	_check(dive_only.last_pass and not dive_only.low_gate_hit and dive_only.coins == 21,
		"C63-3 只俯冲不顶风漏门 21 币（lat %.0f）" % dive_only.lateral)

	# C63-4 不俯冲只顶风：自然滑翔 h52=21m 过门顶（>18m）→ 高度过线漏门 21 币
	var glide: Object = _mk_and_fly(3, 0.35, 27.0, -1.0, 0.4, 1.2)
	_check(glide.last_pass and not glide.low_gate_hit and glide.coins == 21,
		"C63-4 不俯冲只顶风漏门 21 币（%.1fm）" % glide.flight_distance)

	# C63-5 摆烂对照：弱抛判负
	var lazy: Object = _mk_and_fly(3, 0.35, 45.0, 1.2, 0.4, 1.2, 0.3)
	_check(not lazy.last_pass, "C63-5 摆烂弱抛判负（%.1fm）" % lazy.flight_distance)

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c63_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
