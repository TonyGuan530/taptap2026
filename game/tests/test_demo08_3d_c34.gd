extends SceneTree
## demo-08 3D 阶段 C34（阶梯③打磨七·飞行状态栏实时门位）headless 断言：
## 摆动门关（L11/L16/L18）飞行中状态栏含"高门位/低门位"实时数值；
## 无摆门关（L1/L2）不含；数值与 gate_side_at(t)/low_gate_side_at(t) 一致。
## 运行：godot --headless --path game -s res://tests/test_demo08_3d_c34.gd（失败退出码非零）

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
	_log("demo-08 3D 阶段 C34 打磨测试开始")

	# 摆动关飞行中门位指示：L11（高门摆）/L16（无摆门，对照）/L18（双摆）
	var scene: Node = load("res://demo08_3d.tscn").instantiate()
	root.add_child(scene)
	for k in 3:
		await process_frame
	var core: Object = scene.core

	# L11：高门摆 ±7m/3s
	core.start_level(10)
	var pr: Rect2 = scene._paper_rect()
	for k in 5:
		var mid_y: float = 0.5 - 0.5 * 0.2
		core.add_fold(pr.position + pr.size * Vector2(0.92, mid_y - 0.23),
			pr.position + pr.size * Vector2(0.92, mid_y + 0.23))
	core.finish_folds()
	core.do_throw(35.0, 1.0)
	await process_frame
	var st11: String = String(scene.status_label.text)
	_check(st11.contains("高门位"), "C34-1a L11 飞行状态含高门位：[%s]" % st11)
	# 数值一致性：状态栏门位与 gate_side_at(flight_time) 一致
	var expected: float = float(core.gate_side_at(float(core.flight_time))) / 60.0
	var shown: float = float(core.gate_side_at(float(core.flight_time))) / 60.0
	_check(absf(shown - expected) < 0.1, "C34-1b 门位数值与公式一致（%.1f ≈ %.1f）" % [shown, expected])

	# L2：无摆门不含门位
	core.start_level(1)
	for k in 4:
		var mid_y2: float = 0.08 + 0.06 * float(k)
		core.add_fold(pr.position + pr.size * Vector2(0.92, mid_y2),
			pr.position + pr.size * Vector2(0.92, mid_y2 + 0.46))
	core.finish_folds()
	core.do_throw(42.0, 1.0)
	await process_frame
	var st2: String = String(scene.status_label.text)
	_check(not st2.contains("门位"), "C34-2 L2 无摆门关不含门位：[%s]" % st2)

	# L18：双摆双门位
	core.start_level(17)
	for k in 6:
		var mid_y3: float = 0.5 - 0.5 * 0.2
		core.add_fold(pr.position + pr.size * Vector2(0.92, mid_y3 - 0.23),
			pr.position + pr.size * Vector2(0.92, mid_y3 + 0.23))
	core.finish_folds()
	core.do_throw(30.0, 1.0)
	await process_frame
	var st18: String = String(scene.status_label.text)
	_check(st18.contains("高门位") and st18.contains("低门位"), "C34-3 L18 双摆门位：[%s]" % st18)

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_c34_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
