extends SceneTree
## demo-08 3D 阶段 C66（大师篇·L42 时机侧峡）核心不变量（headless，固定 delta=1/60）：
## 纯既有机制组合（无新字段）：逆风 × 左推侧风 -60 × 低门 52m/top18/+240/开窗 2.2-3.0s × 俯冲输入。
## 三轴合流考：俯冲定高度、D 顶风定横位、到达时刻掐进窗里。
## 配方 3×0.35@26° dive=1.2s + D 0.4-1.2s。L1-L41 逐位不变。42 关。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c66.gd（失败退出码非零）

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
	c.start_level(41)
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
	_log("demo-08 3D 阶段 C66 时机侧峡测试开始")

	# C66-1 静态锚：低门 52m/top18/+240/开窗 2.2-3.0s、左推侧风 -60、42 关、low_gate_open() 三态
	var c1: Object = CoreScript.new()
	c1.start_level(41)
	c1.flight_time = 2.0
	var early: bool = c1.low_gate_open()
	c1.flight_time = 2.6
	var mid: bool = c1.low_gate_open()
	c1.flight_time = 3.2
	var late: bool = c1.low_gate_open()
	_check(early == false and mid == true and late == false and int(c1.LEVELS.size()) == 42
		and absf(float(c1.LEVELS[41].low_gate_top) - 18.0) < 1e-6
		and float(c1.side_wind_accel()) == -60.0,
		"C66-1 静态锚：低门时机窗三态 + top18 / 侧风 -60 / 42 关")

	# C66-2 三轴配方：3 折 v=0.35 26° dive=1.2s + D 0.4-1.2s → 过关穿窗内低门，24 = 3 + 7 + 14
	var good: Object = _mk_and_fly(3, 0.35, 26.0, 1.2, 0.4, 1.2)
	_check(good.last_pass and good.low_gate_hit,
		"C66-2 三轴配方过关穿窗内低门（%.1fm）" % good.flight_distance)
	_check(good.coins == 24,
		"C66-2b 收益 24 = 门奖 3 + int(d/10) 7 + 过关奖 14")

	# C66-3 窗外档：不俯冲 → 高度过顶+时间出窗双重漏门 21 币
	var glide: Object = _mk_and_fly(3, 0.35, 26.0, -1.0, 0.4, 1.2)
	_check(glide.last_pass and not glide.low_gate_hit and glide.coins == 21,
		"C66-3 不俯冲档漏门 21 币（%.1fm）" % glide.flight_distance)

	# C66-4 摆烂对照：弱抛判负
	var lazy: Object = _mk_and_fly(3, 0.35, 45.0, 1.2, 0.4, 1.2, 0.3)
	_check(not lazy.last_pass, "C66-4 摆烂弱抛判负（%.1fm）" % lazy.flight_distance)

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c66_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
