extends SceneTree
## demo-08 3D 阶段 C9（阶梯③打磨·逻辑层）：面板信息完整性 headless 断言。
## 终局面板显示加固/铅条级数；菜单规则含七物商店；复盘标记含门横位 side 字段。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c9.gd（失败退出码非零）

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
	_log("demo-08 3D 阶段 C9 打磨测试开始（面板内容，headless）")
	var scene: Node = load("res://demo08_3d.tscn").instantiate()
	root.add_child(scene)
	for k in 3:
		await process_frame
	var core: Object = scene.core

	# C9-1 终局面板强化行含四项可叠加级数
	core.upgrades = {power = 1, wing = 2, stiff = 3, ballast = 1}
	core.total_distance = 123.0
	core.best_distance = 45.2
	core.coins = 33
	scene._show_final()
	var ft: String = String(scene.final_body.text)
	_check(ft.contains("加固 x3") and ft.contains("铅条 x1") and ft.contains("翼面 x2"),
		"C9-1 终局面板显示加固/铅条/翼面级数")

	# C9-2 菜单规则含七物商店说明
	var rules_txt: String = ""
	for c in scene.get_node("HUD/MenuPanel").get_children():
		if c is Label and String(c.text).contains("商店七物"):
			rules_txt = String(c.text)
	_check(rules_txt.contains("纸面加固") and rules_txt.contains("重心铅条") and rules_txt.contains("横向宽度 5m"),
		"C9-2 菜单规则含七物商店与横移说明")

	# C9-3 复盘标记带门横位 side 字段（绘制用）
	core.start_level(1)
	var marks: Array = scene.chart_marks()
	var has_side := false
	for m in marks:
		if m.has("side"):
			has_side = true
	_check(marks.size() == 3 and has_side, "C9-3 L2 复盘标记 3 个且含 side 横位字段")

	# C9-4 商店池描述完整（七物 name/desc 非空）
	var pool_ok := true
	for it in core.SHOP_POOL:
		if String(it.name) == "" or String(it.desc) == "" or int(it.price) <= 0:
			pool_ok = false
	_check(core.SHOP_POOL.size() == 7 and pool_ok, "C9-4 商店七物名称/描述/价格完整")

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c9_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
