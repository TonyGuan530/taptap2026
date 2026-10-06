extends SceneTree
## demo-08 3D 阶段 C56（大师篇·L34 配重峡=顶风马拉松）核心不变量（headless，固定 delta=1/60）：
## 纯既有机制组合（无新字段）：逆风 × 双倍侧风 120 × 极左高门 46m/12m/-660。
## 顶风马拉松：全程按住 A 才够得着极左门（24 币）；松手被风带走（被动过关漏门 21 币）；
## 侧翼配重 1/2 级为余量档（更从容同达）。设计结论在案：输入(240)恒大于风推(120)，
## "必需购买"在横位维度不成立——本关诚实定位为顶风耐力考，配重=余量非门票。
## L1-L33 逐位不变。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c56.gd（失败退出码非零）

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


func _mk_and_fly(n: int, v: float, ang: float, sw: int, hold_a: bool, pw: float = 1.0) -> Object:
	var c: Object = CoreScript.new()
	c.start_level(33)
	c.upgrades.sideWeight = sw
	var pr: Rect2 = c.paper_rect
	for k in n:
		var mid_y: float = 0.5 - 0.5 * v
		c.add_fold(pr.position + pr.size * Vector2(0.92, mid_y - 0.23),
			pr.position + pr.size * Vector2(0.92, mid_y + 0.23))
	c.finish_folds()
	c.do_throw(ang, pw)
	var g := 0
	while String(c.state) == "fly" and g < MAX_STEPS:
		c.lateral_input = -1.0 if hold_a else 0.0
		c.step(DELTA)
		g += 1
	return c


func _run() -> void:
	await process_frame
	_log("demo-08 3D 阶段 C56 配重峡测试开始")

	# C56-1 静态锚：侧风 120、门 -660 极左、34 关
	var c1: Object = CoreScript.new()
	c1.start_level(33)
	_check(float(c1.side_wind_accel()) == 120.0 and absf(float(c1.LEVELS[33].gate_side) + 660.0) < 1e-6
		and int(c1.LEVELS.size()) == 34,
		"C56-1 静态锚：侧风 120 / 门 -660 极左 / 34 关")

	# C56-2 顶风马拉松：全程按住 A → 过关吃极左门，24 = 3 + 7 + 14
	var hold: Object = _mk_and_fly(4, 0.2, 30.0, 0, true)
	_check(hold.last_pass and hold.gate_hit,
		"C56-2 全程顶风过关吃极左门（%.1fm）" % hold.flight_distance)
	_check(hold.coins == 24 and hold.gate_coins == 3,
		"C56-2b 收益 24 = 门奖 3 + int(d/10) 7 + 过关奖 14")

	# C56-3 松手档：不顶风 → 被右风带走漏门，过关 21 币
	var loose: Object = _mk_and_fly(4, 0.2, 30.0, 0, false)
	_check(loose.last_pass and not loose.gate_hit and loose.coins == 21,
		"C56-3 松手被带走漏门 21 币（%.1fm）" % loose.flight_distance)

	# C56-4 配重余量档：1 级与 2 级全程顶风均吃门（余量更从容，非门票）
	var w1: Object = _mk_and_fly(4, 0.2, 30.0, 1, true)
	var w2: Object = _mk_and_fly(4, 0.2, 30.0, 2, true)
	_check(w1.last_pass and w1.gate_hit and w2.last_pass and w2.gate_hit,
		"C56-4 配重 1/2 级余量档同样吃门")

	# C56-5 摆烂对照：弱抛判负
	var lazy: Object = _mk_and_fly(4, 0.2, 45.0, 0, true, 0.3)
	_check(not lazy.last_pass, "C56-5 摆烂弱抛判负（%.1fm）" % lazy.flight_distance)

	# C56-6 标签：逆风＋侧风→
	var scene: Node = load("res://demo08_3d.tscn").instantiate()
	root.add_child(scene)
	for k in 3:
		await process_frame
	scene.core.start_level(33)
	var tag34: String = String(scene.wind_tag_text())
	scene.queue_free()
	await process_frame
	_check(tag34 == "逆风 阻力 x1.25 ＋ 侧风→",
		"C56-6 L34 标签「%s」= 逆风＋侧风→" % tag34)

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c56_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
