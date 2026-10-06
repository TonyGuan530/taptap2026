extends SceneTree
## demo-08 3D 阶段 C50（打磨十四·终局面板端到端）核心不变量（headless）：
## 真·打完 30 关到 final 态，断言终局面板文本：通关行/里程/吃门 N/M/强化四级/部件段全链路渲染。
## C48 只验了计数值，本套验渲染（含「吃门 28/37 扇」C1 基准线）。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c50.gd（失败退出码非零）

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


func _run() -> void:
	await process_frame
	_log("demo-08 3D 阶段 C50 终局面板端到端测试开始")

	var scene: Node = load("res://demo08_3d.tscn").instantiate()
	root.add_child(scene)
	for k in 3:
		await process_frame
	var core: Object = scene.core
	core.rng.seed = 808

	# 全 30 关推进到 final
	var all_pass := true
	for i in 30:
		core.start_level(i)
		_fly_recipe(core, _c1_recipe(i))
		all_pass = all_pass and core.last_pass
		if i < 29:
			core.settle_continue()
			if String(core.state) == "shop":
				core.shop_skip()
	_check(all_pass and String(core.state) == "settle" and core.level_idx == 29,
		"C50-1 全 30 关推进到 L30 结算态")

	# 场景层终局面板渲染
	var go: String = core.settle_continue()
	_check(go == "final" and String(core.state) == "final", "C50-2 L30 结算继续 → final")
	scene._show_final()
	var txt: String = String(scene.final_body.text)
	_check(txt.begins_with("30 关全部飞过终点旗！"),
		"C50-3 通关行「%s…」" % txt.left(14))
	_check(txt.contains("吃门 28/37 扇"),
		"C50-4 吃门统计「28/37 扇」（C1 配方基准线）")
	_check(txt.contains("总飞行") and txt.contains("最远一掷") and txt.contains("金币余额"),
		"C50-5 里程/最远/金币段保留")
	_check(txt.contains("强化：力气 x0 · 翼面 x0 · 加固 x0 · 铅条 x0 · 无特殊部件"),
		"C50-6 强化段与无部件段（本趟未购物）")

	scene.queue_free()
	await process_frame

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c50_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
