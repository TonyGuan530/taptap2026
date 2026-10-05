extends SceneTree
## demo-08 3D 阶段 C41（打磨十·气流区信息接入商店与结算）核心不变量（headless）：
## ① 商店策略提示函数化 shop_strategy_hints（C37 逻辑迁出）+ 补气流区关推荐行；
## ② 结算面板 settle_zone_text：气流带出口高度（双带取热流出口），未飞到出口返回空串。
## 纯显示层，不触碰核心规则。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c41.gd（失败退出码非零）

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


func _run() -> void:
	await process_frame
	_log("demo-08 3D 阶段 C41 气流区信息接入测试开始")

	var scene: Node = load("res://demo08_3d.tscn").instantiate()
	root.add_child(scene)
	for k in 3:
		await process_frame

	# C41-1 商店策略提示：L24（逆风+气流区）两行 / L11（摆门）一行 / L6（侧风）一行 / L1 空
	scene.core.start_level(23)
	var h24: Array = scene.shop_strategy_hints()
	_check(h24.size() == 2 and String(h24[0]) == "逆风关：纸面加固降阻力"
		and String(h24[1]) == "气流区关：翼面升力扛谷，螺旋桨保速乘流",
		"C41-1a L24 提示两行（逆风+气流区）")
	scene.core.start_level(10)
	var h11: Array = scene.shop_strategy_hints()
	_check(h11.size() == 1 and String(h11[0]) == "摆门关：配平仪精确切门",
		"C41-1b L11 提示一行（摆门）")
	scene.core.start_level(5)
	var h6: Array = scene.shop_strategy_hints()
	_check(h6.size() == 1 and String(h6[0]) == "侧风关：重心铅条驯配平",
		"C41-1c L6 提示一行（侧风）")
	scene.core.start_level(0)
	_check(scene.shop_strategy_hints().is_empty(), "C41-1d L1 无提示")

	# C41-2 结算出口高度：L24 谷出口 / L25 热流出口（双带取热流出口）/ 无带空串
	var core: Object = scene.core
	core.start_level(23)
	var pr: Rect2 = core.paper_rect
	for k in 4:
		var mid_y: float = 0.5 - 0.5 * 0.2
		core.add_fold(pr.position + pr.size * Vector2(0.92, mid_y - 0.23),
			pr.position + pr.size * Vector2(0.92, mid_y + 0.23))
	core.finish_folds()
	core.do_throw(27.0, 1.0)
	var g := 0
	while String(core.state) == "fly" and g < MAX_STEPS:
		core.step(DELTA)
		g += 1
	var zt24: String = String(scene.settle_zone_text())
	_check(core.last_pass and zt24.begins_with("谷出口 ") and zt24.contains("米"),
		"C41-2a L24 结算「%s」= 谷出口高度" % zt24)
	core.start_level(24)
	var pr25: Rect2 = core.paper_rect
	for k in 4:
		var mid_y25: float = 0.5 - 0.5 * 0.2
		core.add_fold(pr25.position + pr25.size * Vector2(0.92, mid_y25 - 0.23),
			pr25.position + pr25.size * Vector2(0.92, mid_y25 + 0.23))
	core.finish_folds()
	core.do_throw(40.0, 1.0)
	var g25 := 0
	while String(core.state) == "fly" and g25 < MAX_STEPS:
		core.step(DELTA)
		g25 += 1
	var zt25: String = String(scene.settle_zone_text())
	_check(core.last_pass and zt25.begins_with("热流出口 ") and zt25.contains("米"),
		"C41-2b L25 结算「%s」= 热流出口高度（双带取第二带）" % zt25)
	core.start_level(11)
	core.trail = []
	_check(String(scene.settle_zone_text()) == "",
		"C41-2c L12 无带返回空串")

	# C41-3 摆烂未飞到出口：trail 在谷出口前结束 → 空串
	core.start_level(23)
	var pr3: Rect2 = core.paper_rect
	for k in 4:
		var mid_y3: float = 0.5 - 0.5 * 0.2
		core.add_fold(pr3.position + pr3.size * Vector2(0.92, mid_y3 - 0.23),
			pr3.position + pr3.size * Vector2(0.92, mid_y3 + 0.23))
	core.finish_folds()
	core.do_throw(45.0, 0.3)
	var g3 := 0
	while String(core.state) == "fly" and g3 < MAX_STEPS:
		core.step(DELTA)
		g3 += 1
	_check(not core.last_pass and String(scene.settle_zone_text()) == "",
		"C41-3 摆烂未到谷出口返回空串")

	scene.queue_free()
	await process_frame

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c41_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
