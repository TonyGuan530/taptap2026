extends SceneTree
## demo-08 3D 阶段 C65（阶梯②·L41 时机俯冲）核心不变量（headless，固定 delta=1/60）：
## 规则扩展（已记录）：low_gate_open_t0/t1 低门时间窗——时机窗从高门推广到低门，缺省 0=常开。
## L41 时机俯冲（无风 × 低门 66m/top16/开窗 2.4-3.4s × 俯冲）：俯冲深度×到达时机双约束耦合。
## 配方 5×0.35@28° dive=1.8s。L1-L40 逐位不变。41 关。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c65.gd（失败退出码非零）

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


func _mk_and_fly(n: int, v: float, ang: float, dive_at: float, pw: float = 1.0) -> Object:
	var c: Object = CoreScript.new()
	c.start_level(40)
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
		c.step(DELTA)
		g += 1
	return c


func _run() -> void:
	await process_frame
	_log("demo-08 3D 阶段 C65 时机俯冲测试开始")

	# C65-1 静态锚：低门时间窗 2.4-3.4s、门 66m/top16、41 关、low_gate_open() 三态
	var c1: Object = CoreScript.new()
	c1.start_level(40)
	c1.flight_time = 2.0
	var early: bool = c1.low_gate_open()
	c1.flight_time = 2.8
	var mid: bool = c1.low_gate_open()
	c1.flight_time = 3.6
	var late: bool = c1.low_gate_open()
	_check(early == false and mid == true and late == false and int(c1.LEVELS.size()) == 41
		and absf(float(c1.LEVELS[40].low_gate_top) - 16.0) < 1e-6,
		"C65-1 低门时机窗三态 + 门 top16 + 41 关")

	# C65-2 常开回归：L37（无低门窗）任意时刻 low_gate_open 恒真
	c1.start_level(36)
	c1.flight_time = 0.5
	var o1: bool = c1.low_gate_open()
	c1.flight_time = 13.0
	var o2: bool = c1.low_gate_open()
	_check(o1 and o2, "C65-2 L37 常开回归（缺省路径逐位不变）")

	# C65-3 配方：5 折 v=0.35 28° dive=1.8s → 过关穿窗内低门，24 = 3 + 7 + 14
	var good: Object = _mk_and_fly(5, 0.35, 28.0, 1.8)
	_check(good.last_pass and good.low_gate_hit,
		"C65-3 配方过关穿窗内低门（%.1fm）" % good.flight_distance)
	_check(good.coins == 24,
		"C65-3b 收益 24 = 门奖 3 + int(d/10) 7 + 过关奖 14")

	# C65-4 不俯冲档：自然滑翔过顶（>16m）且窗外（t<2.4）双重漏门 21 币
	var glide: Object = _mk_and_fly(5, 0.35, 28.0, -1.0)
	_check(glide.last_pass and not glide.low_gate_hit and glide.coins == 21,
		"C65-4 不俯冲档漏门 21 币（%.1fm）" % glide.flight_distance)

	# C65-5 摆烂对照：弱抛判负
	var lazy: Object = _mk_and_fly(5, 0.35, 45.0, 1.8, 0.3)
	_check(not lazy.last_pass, "C65-5 摆烂弱抛判负（%.1fm）" % lazy.flight_distance)

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c65_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
