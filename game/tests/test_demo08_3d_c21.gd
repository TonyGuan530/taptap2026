extends SceneTree
## demo-08 3D 阶段 C21（阶梯③打磨四·摆动门摆幅标注）headless 断言：
## chart_marks 含 swing/period 数据；chart_gate_swing_label 静止空串/摆幅格式；
## 摆动关（L11/L16/L18）标注含摆幅，静止关（L2）不含。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c21.gd（失败退出码非零）

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


func _marks_of(level: int) -> Dictionary:
	var scene: Node = load("res://demo08_3d.tscn").instantiate()
	root.add_child(scene)
	for k in 3:
		await process_frame
	scene.core.start_level(level)
	var marks: Array = scene.chart_marks()
	scene.queue_free()
	await process_frame
	return {marks = marks, scene = scene}


func _run() -> void:
	await process_frame
	_log("demo-08 3D 阶段 C21 打磨测试开始")

	# C21-1 摆幅标注文本函数：静止空串 / 摆幅格式
	var scene: Node = load("res://demo08_3d.tscn").instantiate()
	root.add_child(scene)
	for k in 3:
		await process_frame
	_check(scene.chart_gate_swing_label(0.0, 0.0) == "", "C21-1a 静止门摆幅标注空串")
	_check(scene.chart_gate_swing_label(7.0, 3.0) == " ±7m/3.0s", "C21-1b 摆幅标注格式：[%s]" % scene.chart_gate_swing_label(7.0, 3.0))

	# C21-2 marks 数据：L11 摆门 7m/3s；L2 静止门 swing 0
	var m11: Dictionary = await _marks_of(10)
	var m11_high := {}
	for m in m11.marks:
		if String(m.kind) == "high":
			m11_high = m
	_check(absf(float(m11_high.get("swing", 0.0)) - 7.0) < 1e-9 and absf(float(m11_high.get("period", 0.0)) - 3.0) < 1e-9,
		"C21-2a L11 高门标记含 swing 7m/period 3s")
	var m2: Dictionary = await _marks_of(1)
	var m2_high := {}
	for m in m2.marks:
		if String(m.kind) == "high":
			m2_high = m
	_check(absf(float(m2_high.get("swing", 0.0))) < 1e-9, "C21-2b L2 静止门 swing 0")

	# C21-3 组装标注：L11 高门全标注 = "45m 门 ±7m/3.0s"
	var full: String = scene.chart_gate_label(float(m11_high.x), float(m11_high.side)) + scene.chart_gate_swing_label(float(m11_high.swing), float(m11_high.period))
	_check(full == "45m 门 ±7m/3.0s", "C21-3 L11 高门全标注：[%s]" % full)

	# C21-4 L18 双摆门标记：高门 ±4m/3s、低门 ±5m/3s
	var m18: Dictionary = await _marks_of(17)
	var m18_high := {}
	var m18_low := {}
	for m in m18.marks:
		if String(m.kind) == "high":
			m18_high = m
		if String(m.kind) == "low":
			m18_low = m
	_check(absf(float(m18_high.get("swing", 0.0)) - 4.0) < 1e-9 and absf(float(m18_low.get("swing", 0.0)) - 5.0) < 1e-9,
		"C21-4 L18 双摆门标记：高门 swing %.0fm / 低门 swing %.0fm" % [float(m18_high.get("swing", 0.0)), float(m18_low.get("swing", 0.0))])

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c21_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
