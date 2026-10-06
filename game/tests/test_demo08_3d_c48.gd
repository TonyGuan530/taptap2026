extends SceneTree
## demo-08 3D 阶段 C48（打磨十二·终局面板吃门统计）核心不变量（headless，固定 delta=1/60）：
## gates_offered（每关首次进入计一次，失败重试重入去重）/ gates_eaten（门奖结算点累计）。
## 会计口径：M=本趟出现过的门（含没吃到的），N=吃下的门；reset_run 全清。纯统计非规则变化。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c48.gd（失败退出码非零）

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


func _fly_current(c: Object, n: int, v: float, ang: float, pw: float = 1.0) -> void:
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


func _run() -> void:
	await process_frame
	_log("demo-08 3D 阶段 C48 吃门统计测试开始")

	# C48-1 迷你趟：L1(0 扇) → L2(2 扇：先弱抛失败，重试后过关吃高门) → L3(0 扇) → L4(2 扇)
	var c: Object = CoreScript.new()
	c.rng.seed = 808
	c.start_level(0)
	_fly_current(c, 2, 0.2, 30.0)          # L1 无门
	c.settle_continue()
	c.start_level(1)
	_fly_current(c, 4, 0.2, 42.0, 0.3)     # L2 弱抛故意失败（逆风 1.25 拖累，无推力救场）
	_check(not c.last_pass and int(c.gates_offered) == 2 and int(c.gates_eaten) == 0,
		"C48-1 L2 弱抛失败（offered=2 eaten=0）")
	c.settle_continue()                    # retry → start_level(1) 重入
	_check(int(c.gates_offered) == 2, "C48-1b 重试重入去重（offered 仍 2）")
	_fly_current(c, 4, 0.2, 42.0)          # L2 正式配方过关吃高门
	_check(c.last_pass and c.gate_hit and int(c.gates_offered) == 2 and int(c.gates_eaten) == 1,
		"C48-1c 重试过关吃高门（offered=2 eaten=1）")
	c.settle_continue()
	if String(c.state) == "shop":
		c.shop_skip()
	c.start_level(2)
	_fly_current(c, 5, 0.2, 35.0, 0.9)     # C1 L3 配方（0.9 力）过关
	_check(int(c.gates_offered) == 2 and int(c.gates_eaten) == 1,
		"C48-1d L3 无门不变（offered=2 eaten=1）")

	# C48-2 推进 L4：双门入场 offered=4
	if c.last_pass:
		c.settle_continue()                # shop
		c.shop_skip()
		c.start_level(3)                   # L4 双门 → offered +2
	var offered_l4: int = int(c.gates_offered)
	_check(offered_l4 == 4, "C48-2 L4 双门入场 offered=4（2+0+2）")
	_check(int(c.gates_eaten) == 1, "C48-2b eaten 仍 1（L3 未吃门）")

	# C48-3 reset_run 全清
	c.reset_run()
	_check(int(c.gates_offered) == 0 and int(c.gates_eaten) == 0 and int(c.offered_mark) == -1,
		"C48-3 reset_run 全清（offered/eaten/mark）")

	# C48-4 全 30 关趟（C1 流程）末端对账：offered = 各关门数总和
	var f: Object = CoreScript.new()
	f.rng.seed = 808
	var offered_expect := 0
	for i in 37:
		f.start_level(i)
		offered_expect += (1 if float(f.LEVELS[i].get("gate_x", 0.0)) > 0.0 else 0) + (1 if float(f.LEVELS[i].get("low_gate_x", 0.0)) > 0.0 else 0)
		var r: Array = _c1_recipe(i)
		_fly_recipe(f, r)
		if i < 29:
			f.settle_continue()
			if String(f.state) == "shop":
				f.shop_skip()
	_check(f.last_pass and int(f.gates_offered) == offered_expect,
		"C48-4 全趟对账：offered %d = 逐关配置总和 %d" % [int(f.gates_offered), offered_expect])
	_log("  （全趟吃门 %d/%d 扇）" % [int(f.gates_eaten), int(f.gates_offered)])

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var fl := FileAccess.open("user://test_demo08_3d_c48_log.txt", FileAccess.WRITE)
	if fl:
		fl.store_string("\n".join(log_lines))
		fl.flush()
	quit(1 if fails > 0 else 0)


func _c1_recipe(i: int) -> Array:
	match i:
		0: return [2, 30.0, 1.0, 0.0, 0.0]
		1: return [4, 42.0, 1.0, 0.0, 0.0]
		2: return [5, 35.0, 0.9, 0.0, 0.0]
		3: return [4, 35.0, 1.0, -1.0, 1.2]
		4: return [6, 45.0, 1.0, 0.0, 0.0]
		5: return [4, 30.0, 1.0, 1.0, 0.4]
		6: return [5, 30.0, 1.0, -1.0, 0.8]
		7: return [5, 30.0, 1.0, 0.0, 0.0]
		8: return [5, 30.0, 1.0, 1.0, 0.8]
		9: return [5, 30.0, 1.0, 1.0, 0.6]
		10: return [5, 35.0, 1.0, 0.0, 0.0]
		11: return [5, 35.0, 1.0, 0.0, 0.0, 0.35]
		12: return [5, 30.0, 1.0, 1.0, 0.8]
		13: return [5, 30.0, 1.0, 1.0, 0.0, 0.2, 30.2, 61.8]
		14: return [6, 30.0, 1.0, -1.0, 99.0]
		15: return [5, 30.0, 1.0, 0.0, 0.0]
		16: return [5, 30.0, 1.0, 1.0, 0.8, 0.2]
		17: return [6, 30.0, 1.0, 0.0, 0.0, 0.2]
		18: return [5, 30.0, 1.0, 1.0, 0.0, 0.2, 30.2, 54.8]
		19: return [5, 30.0, 1.0, -1.0, 0.0, -0.5, 30.2, 50.4]
		21: return [4, 35.0, 1.0, -1.0, 1.0, 0.2]
		22: return [4, 30.0, 1.0, 1.0, 1.0, 0.2]
		23: return [4, 27.0, 1.0, 0.0, 0.0, 0.2]
		24: return [4, 40.0, 1.0, 0.0, 0.0, 0.2]
		25: return [4, 28.0, 1.0, 0.0, 0.0, 0.35]
		26: return [4, 40.0, 1.0, 0.0, 0.0, 0.2]
		27: return [4, 24.0, 1.0, 0.0, 0.0, 0.35]
		28: return [4, 30.0, 1.0, 0.0, 0.0, 0.2]
		29: return [4, 32.0, 1.0, 0.0, 0.0, 0.2]
	return [3, 30.0, 1.0, 0.0, 0.0]


func _fly_recipe(c: Object, r: Array) -> void:
	if r.size() > 5:
		var v: float = float(r[5])
		var pr: Rect2 = c.paper_rect
		for k in int(r[0]):
			var mid_y: float = 0.5 - 0.5 * v
			c.add_fold(pr.position + pr.size * Vector2(0.92, mid_y - 0.23),
				pr.position + pr.size * Vector2(0.92, mid_y + 0.23))
	else:
		_good_folds(c, int(r[0]))
	c.finish_folds()
	c.do_throw(float(r[1]), float(r[2]))
	var g := 0
	while String(c.state) == "fly" and g < MAX_STEPS:
		var input_on: bool
		if r.size() > 7:
			var lo_px: float = 60.0 + float(r[6]) * 60.0
			var hi_px: float = 60.0 + float(r[7]) * 60.0
			input_on = c.plane_pos.x >= lo_px and c.plane_pos.x < hi_px
		else:
			input_on = c.flight_time < float(r[4])
		c.lateral_input = float(r[3]) if input_on else 0.0
		c.step(DELTA)
		g += 1


func _good_folds(c: Object, n: int) -> void:
	var pr: Rect2 = c.paper_rect
	for k in n:
		var mid_y: float = 0.5 - 0.5 * 0.2
		c.add_fold(pr.position + pr.size * Vector2(0.92, mid_y - 0.23),
			pr.position + pr.size * Vector2(0.92, mid_y + 0.23))
