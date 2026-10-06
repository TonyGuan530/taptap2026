extends SceneTree
## demo-08 3D 阶段 C53（大师篇·L32 狂风精准）核心不变量（headless，固定 delta=1/60）：
## 纯既有机制组合（无新字段）：逆风 1.25 × 双倍侧风 120（全系列最强横风）× 远右高门 44m/12m/+700。
## 全帆乘风课：被动入门带 23 币；侧翼配重 1 级即漏门（削弱风推反而漂不到远带——物品的场合性）。
## L1-L31 逐位不变。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c53.gd（失败退出码非零）

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


func _mk_and_fly(n: int, v: float, ang: float, sw: int, pw: float = 1.0) -> Object:
	var c: Object = CoreScript.new()
	c.start_level(31)
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
		c.step(DELTA)
		g += 1
	return c


func _run() -> void:
	await process_frame
	_log("demo-08 3D 阶段 C53 狂风精准测试开始")

	# C53-1 静态锚：侧风 120 双倍、LEVELS 32 关
	var c1: Object = CoreScript.new()
	c1.start_level(31)
	_check(float(c1.side_wind_accel()) == 120.0 and int(c1.LEVELS.size()) == 33,
		"C53-1 静态锚：侧风 120 全系列最强 / 33 关")

	# C53-2 乘风配方：4 折 v=0.2 30° 无舵 → 过关吃远右高门，23 = 3 + 6 + 14
	var go1: Object = _mk_and_fly(4, 0.2, 30.0, 0)
	_check(go1.last_pass and go1.gate_hit,
		"C53-2 全帆乘风过关吃门（%.1fm）" % go1.flight_distance)
	_check(go1.coins == 23 and go1.gate_coins == 3,
		"C53-2b 收益 23 = 门奖 3 + int(d/10) 6 + 过关奖 14")

	# C53-3 物品场合性：同配方 + 1 级侧翼配重 → 风推被削漂不到远带漏门（过关无门奖）
	var sw1: Object = _mk_and_fly(4, 0.2, 30.0, 1)
	_check(sw1.last_pass and not sw1.gate_hit and sw1.coins == 20,
		"C53-3 配重 1 级漏门 20 币（乘风课的反面：%.0f 出带）" % sw1.lateral)

	# C53-4 摆烂对照：弱抛判负
	var lazy: Object = _mk_and_fly(4, 0.2, 45.0, 0, 0.3)
	_check(not lazy.last_pass, "C53-4 摆烂弱抛判负（%.1fm）" % lazy.flight_distance)

	# C53-5 标签：逆风＋侧风→（120 档不写数值，箭头语义不变）
	var scene: Node = load("res://demo08_3d.tscn").instantiate()
	root.add_child(scene)
	for k in 3:
		await process_frame
	scene.core.start_level(31)
	var tag32: String = String(scene.wind_tag_text())
	scene.queue_free()
	await process_frame
	_check(tag32 == "逆风 阻力 x1.25 ＋ 侧风→",
		"C53-5 L32 标签「%s」= 逆风＋侧风→" % tag32)

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c53_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
