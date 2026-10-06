extends SceneTree
## demo-08 3D 阶段 C61（阶梯②新输入·L37 俯冲峡）核心不变量（headless，固定 delta=1/60）：
## 规则变化（已记录）：dive_input（S/↓）+ DIVE_ACCEL=320px/s² 额外下压——投掷后垂直操控从无到有。
## L37 俯冲峡（无风 × 低门 70m/top21）：不俯冲自然滑翔 26m 过顶漏门；2.0-2.2s 起俯冲压到 19m 穿门 24 币；
## 2.4s 起太晚漏门 21 币——俯冲时机是唯一判别。设计结论在案：高低门互斥规则下双吃不可行，改纯低门俯冲课。
## 37 关。缺省 dive_input=false，既有 36 关逐位不变。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c61.gd（失败退出码非零）

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
	c.start_level(36)
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
	_log("demo-08 3D 阶段 C61 俯冲峡测试开始")

	# C61-1 静态锚：低门 70m/top21、36+1=37 关、缺省 dive_input=false
	var c1: Object = CoreScript.new()
	c1.start_level(36)
	_check(absf(float(c1.LEVELS[36].low_gate_x) - 70.0) < 1e-6
		and absf(float(c1.LEVELS[36].low_gate_top) - 21.0) < 1e-6
		and c1.dive_input == false and int(c1.LEVELS.size()) == 38,
		"C61-1 静态锚：低门 70m/top21 / 缺省不俯冲 / 37 关")

	# C61-2 俯冲配方：4 折 v=0.35 30°、2.0s 起俯冲 → 过关穿低门，24 = 3 + 7 + 14
	var good: Object = _mk_and_fly(4, 0.35, 30.0, 2.0)
	_check(good.last_pass and good.low_gate_hit,
		"C61-2 俯冲配方过关穿低门（%.1fm）" % good.flight_distance)
	_check(good.coins == 24,
		"C61-2b 收益 24 = 低门奖 3 + int(d/10) 7 + 过关奖 14")

	# C61-3 太晚档：2.4s 起俯冲 → 已过门横位上方，漏门 21 币
	var late: Object = _mk_and_fly(4, 0.35, 30.0, 2.4)
	_check(late.last_pass and not late.low_gate_hit and late.coins == 21,
		"C61-3 太晚档漏门 21 币（%.1fm）" % late.flight_distance)

	# C61-4 不俯冲档：自然滑翔 26m 过顶，漏门 21 币
	var glide: Object = _mk_and_fly(4, 0.35, 30.0, -1.0)
	_check(glide.last_pass and not glide.low_gate_hit and glide.coins == 21,
		"C61-4 不俯冲自然滑翔漏门 21 币（%.1fm）" % glide.flight_distance)

	# C61-5 摆烂对照：弱抛判负
	var lazy: Object = _mk_and_fly(4, 0.35, 45.0, 2.0, 0.3)
	_check(not lazy.last_pass, "C61-5 摆烂弱抛判负（%.1fm）" % lazy.flight_distance)

	# C61-6 物理验证：同机同掷，俯冲版下坠显著快于滑翔版（DIVE_ACCEL 生效）
	var no_dive: Object = _mk_and_fly(4, 0.35, 30.0, -1.0)
	var with_dive: Object = CoreScript.new()
	with_dive.start_level(36)
	var prd: Rect2 = with_dive.paper_rect
	for k in 4:
		var mid_d: float = 0.5 - 0.5 * 0.35
		with_dive.add_fold(prd.position + prd.size * Vector2(0.92, mid_d - 0.23),
			prd.position + prd.size * Vector2(0.92, mid_d + 0.23))
	with_dive.finish_folds()
	with_dive.do_throw(30.0, 1.0)
	var gd := 0
	while String(with_dive.state) == "fly" and gd < 400:   # 400 帧 ≈ 6.7s 内俯冲下坠差异明显
		with_dive.dive_input = with_dive.flight_time >= 1.0
		with_dive.step(DELTA)
		no_dive.step(DELTA)   # 同步推进对照版（其 dive 恒 false 已在初值）
		gd += 1
	var h_no: float = (460.0 - float(no_dive.plane_pos.y)) / 60.0
	var h_yes: float = (460.0 - float(with_dive.plane_pos.y)) / 60.0
	_check(h_yes < h_no - 1.0,
		"C61-6 俯冲下坠更快（俯冲 %.1fm vs 滑翔 %.1fm @400帧）" % [h_yes, h_no])

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c61_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
