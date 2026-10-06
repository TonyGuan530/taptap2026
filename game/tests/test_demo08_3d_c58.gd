extends SceneTree
## demo-08 3D 阶段 C58（打磨十六·菜单大师篇标识）核心不变量（headless）：
## _go_menu 刷新时 L31+ 按钮金色字体覆盖 + 悬停提示「大师篇：…」，主线按钮不受影响。
## 纯显示层，不触碰核心规则。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c58.gd（失败退出码非零）

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
	_log("demo-08 3D 阶段 C58 菜单大师篇标识测试开始")

	var scene: Node = load("res://demo08_3d.tscn").instantiate()
	root.add_child(scene)
	for k in 3:
		await process_frame
	var core: Object = scene.core

	# C58-1 主线按钮：无金色覆盖、tooltip 无大师前缀
	scene._go_menu()
	var b0: Button = scene.level_buttons[0]
	var c0: Color = b0.get_theme_color("font_color")
	_check(String(b0.tooltip_text).begins_with("折纸三参数") == false and not String(b0.tooltip_text).begins_with("大师篇："),
		"C58-1a 主线按钮 tooltip 无大师前缀")
	var c_default: Color = Color("111111")

	# C58-2 大师按钮：金色覆盖 + tooltip 大师前缀（解锁态文本）
	core.unlocked = 33   # L35（index 34）保持锁定态
	scene._go_menu()
	var b30: Button = scene.level_buttons[30]
	var b34: Button = scene.level_buttons[34]
	var c30: Color = b30.get_theme_color("font_color")
	var c34: Color = b34.get_theme_color("font_color")
	_check(String(b30.tooltip_text).begins_with("大师篇：") and String(b34.tooltip_text).begins_with("大师篇："),
		"C58-2a L31/L35 tooltip 大师前缀")
	_check(c30 == Color("9c6f19") and c34 == Color("9c6f19") and c30 != c_default,
		"C58-2b L31/L35 金色字体覆盖（9c6f19）")

	# C58-3 解锁边界：L31 解锁文本正常、L35 未解锁文本不破坏大师标识
	_check(String(b30.text).begins_with("第31关 · ") and String(b34.text).contains("未解锁"),
		"C58-3 解锁/未解锁文本共存（%s / %s）" % [String(b30.text).left(10), String(b34.text).left(12)])

	# C58-4 主线按钮颜色不受波及（重新 _go_menu 后 b0 仍默认色）
	scene._go_menu()
	var c0b: Color = (scene.level_buttons[0] as Button).get_theme_color("font_color")
	_check(c0b != Color("9c6f19"), "C58-4 主线按钮颜色不波及")

	scene.queue_free()
	await process_frame

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c58_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
