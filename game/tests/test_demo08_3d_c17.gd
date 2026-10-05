extends SceneTree
## demo-08 3D 阶段 C17（阶梯③打磨·信息完整性二）headless 断言：
## 商店状态栏"店内 N 件"随购买递减；复盘小图门线标注文本（横位/静止门格式）。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c17.gd（失败退出码非零）

const CoreScript = preload("res://demo08_3d/flight_core.gd")

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
	_log("demo-08 3D 阶段 C17 打磨测试开始")
	var scene: Node = load("res://demo08_3d.tscn").instantiate()
	root.add_child(scene)
	for k in 3:
		await process_frame
	var core: Object = scene.core

	# C17-1 商店状态栏店内件数：进入商店 3 件 → 购买后 2 件
	scene._go_menu()
	core.upgrades = {power = 0, wing = 0, stiff = 0, ballast = 0}
	core.owned = ["prop", "trimtool", "tough"]
	core.coins = 50
	core.rng.seed = 808
	scene._go_menu()
	core.enter_shop()
	await process_frame
	var st1: String = String(scene.status_label.text)
	_check(st1.contains("店内 3 件"), "C17-1a 进店状态栏含店内 3 件：[%s]" % st1)
	var bought: bool = core.buy(0)
	await process_frame
	var st2: String = String(scene.status_label.text)
	_check(bought and st2.contains("店内 2 件"), "C17-1b 购买后状态栏店内 2 件：[%s]" % st2)

	# C17-2 复盘小图门线标注文本：静止门 / 横位门格式
	var lbl_static: String = scene.chart_gate_label(34.0, 0.0)
	_check(lbl_static == "34m 门", "C17-2a 静止门标注：[%s]" % lbl_static)
	var lbl_side: String = scene.chart_gate_label(40.0, -4.0)
	_check(lbl_side == "40m 门-4m", "C17-2b 横位门标注：[%s]" % lbl_side)
	var lbl_side2: String = scene.chart_gate_label(48.0, 2.0)
	_check(lbl_side2 == "48m 门+2m", "C17-2c 横位门标注正号：[%s]" % lbl_side2)

	# C17-3 L12 marks 含 side 数据供标注使用
	core.start_level(11)
	var marks: Array = scene.chart_marks()
	var has_side := false
	for m in marks:
		if m.has("side"):
			has_side = true
	_check(marks.size() == 2 and has_side, "C17-3 L12 复盘标记 2 个且含 side 字段")

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c17_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
