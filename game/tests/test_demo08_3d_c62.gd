extends SceneTree
## demo-08 3D 阶段 C62（大师篇·L38 俯冲摆门）核心不变量（headless，固定 delta=1/60）：
## 纯既有机制组合（无新字段）：无风 × 摆动低门 66m/top12/0±360/3s × 俯冲输入。
## 双时序复合课：俯冲定高度（1.4-1.6s 起跳压到门下）、摆相定横位，1.8s 起即漏、不俯冲漏。
## L1-L37 逐位不变。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c62.gd（失败退出码非零）

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
	c.start_level(37)
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
	_log("demo-08 3D 阶段 C62 俯冲摆门测试开始")

	# C62-1 静态锚：摆动低门 66m/top12/0±360/3s、37+1=38 关、摆动公式两极
	var c1: Object = CoreScript.new()
	c1.start_level(37)
	_check(absf(float(c1.LEVELS[37].low_gate_x) - 66.0) < 1e-6
		and absf(float(c1.LEVELS[37].low_gate_top) - 12.0) < 1e-6
		and absf(float(c1.low_gate_side_at(0.75)) - 360.0) < 1e-6
		and absf(float(c1.low_gate_side_at(2.25)) + 360.0) < 1e-6
		and int(c1.LEVELS.size()) == 38,
		"C62-1 静态锚：摆动低门 66m/top12/±360/3s / 38 关")

	# C62-2 双时序配方：5 折 v=0.35 26°、1.6s 起俯冲 → 过关穿摆动低门，24 = 3 + 7 + 14
	var good: Object = _mk_and_fly(5, 0.35, 26.0, 1.6)
	_check(good.last_pass and good.low_gate_hit,
		"C62-2 双时序配方过关穿摆动低门（%.1fm）" % good.flight_distance)
	_check(good.coins == 24,
		"C62-2b 收益 24 = 门奖 3 + int(d/10) 7 + 过关奖 14")

	# C62-3 太晚档：1.8s 起俯冲 → 高度过了门顶（相位/高度双失），漏门 21 币
	var late: Object = _mk_and_fly(5, 0.35, 26.0, 1.8)
	_check(late.last_pass and not late.low_gate_hit and late.coins == 21,
		"C62-3 太晚档漏门 21 币（%.1fm）" % late.flight_distance)

	# C62-4 不俯冲档：自然滑翔过顶漏门 21 币
	var glide: Object = _mk_and_fly(5, 0.35, 26.0, -1.0)
	_check(glide.last_pass and not glide.low_gate_hit and glide.coins == 21,
		"C62-4 不俯冲档漏门 21 币（%.1fm）" % glide.flight_distance)

	# C62-5 摆烂对照：弱抛判负
	var lazy: Object = _mk_and_fly(5, 0.35, 45.0, 1.6, 0.3)
	_check(not lazy.last_pass, "C62-5 摆烂弱抛判负（%.1fm）" % lazy.flight_distance)

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c62_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
