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


## 三十五关规范配方表单源（C80 提取）：新增关卡只改 campaign_recipes.gd 一处
var Recipes := preload("res://tests/campaign_recipes.gd")


func _c1_recipe(i: int) -> Array:
	return Recipes.recipe(i)

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
		c.dive_input = r.size() > 8 and c.flight_time >= float(r[8])   # 第 9 元素=俯冲起始秒（C88）
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
	for i in 40:
		core.start_level(i)
		_fly_recipe(core, _c1_recipe(i))
		all_pass = all_pass and core.last_pass
		if i < 29:
			core.settle_continue()
			if String(core.state) == "shop":
				core.shop_skip()
	_check(all_pass and String(core.state) == "settle" and core.level_idx == 39,
		"C50-1 全 40 关推进到 L40 结算态")

	# 场景层终局面板渲染
	var go: String = core.settle_continue()
	_check(go == "final" and String(core.state) == "final", "C50-2 L40 结算继续 → final")
	scene._show_final()
	var txt: String = String(scene.final_body.text)
	_check(txt.begins_with("40 关全部飞过终点旗！"),
		"C50-3 通关行「%s…」" % txt.left(14))
	_check(txt.contains("吃门 35/47 扇"),
		"C50-4 吃门统计「35/47 扇」（C1 配方基准线，L38/39 窄容差门在种子基线下脱靶）")
	_check(txt.contains("总飞行") and txt.contains("最远一掷") and txt.contains("金币余额"),
		"C50-5 里程/最远/金币段保留")
	_check(txt.contains("强化：力气 x0 · 翼面 x0 · 加固 x0 · 铅条 x0 · 侧配 x0 · 无特殊部件"),
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
