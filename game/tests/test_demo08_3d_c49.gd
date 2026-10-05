extends SceneTree
## demo-08 3D 阶段 C49（打磨十三·商店状态栏强化明细）核心不变量（headless）：
## shop_status_text 函数化：原金币/店内件数/下一关段保留，追加当前强化四级明细。
## 纯显示层，不触碰核心规则。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c49.gd（失败退出码非零）

const CoreScript := preload("res://demo08_3d/flight_core.gd")

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
	_log("demo-08 3D 阶段 C49 商店状态栏测试开始")

	var scene: Node = load("res://demo08_3d.tscn").instantiate()
	root.add_child(scene)
	for k in 3:
		await process_frame
	var core: Object = scene.core

	# C49-1 零强化：基础段完整 + 强化四级全 x0
	core.start_level(1)   # L2 过关后进店 → level_idx=1，带入第 3 关
	core.coins = 7
	core.enter_shop()
	var t0: String = String(scene.shop_status_text())
	_check(t0 == "肉鸽商店 · 金币 7 · 店内 3 件 · 买强化带入第 3 关 · 强化：力气 x0 · 翼面 x0 · 加固 x0 · 铅条 x0",
		"C49-1 零强化文本「%s」" % t0)

	# C49-2 持强化：力气 x2 翼面 x1 加固 x1 铅条 x2 如实渲染
	core.upgrades = {power = 2, wing = 1, stiff = 1, ballast = 2}
	core.coins = 15
	var t2: String = String(scene.shop_status_text())
	_check(t2.contains("金币 15") and t2.contains("力气 x2 · 翼面 x1 · 加固 x1 · 铅条 x2"),
		"C49-2 持强化明细「%s」" % t2)

	# C49-3 关卡推进联动：带入第 N 关随 level_idx 变化
	core.start_level(5)
	core.coins = 3
	var t5: String = String(scene.shop_status_text())
	_check(t5.contains("带入第 7 关") and t5.contains("金币 3"),
		"C49-3 L6 入店带入第 7 关「%s」" % t5)

	# C49-4 静止锚：文本含店内件数（种子商店恒 3 件）与原「肉鸽商店」抬头
	_check(t0.begins_with("肉鸽商店") and t0.contains("店内 3 件"),
		"C49-4 抬头与件数保留")

	scene.queue_free()
	await process_frame

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c49_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
