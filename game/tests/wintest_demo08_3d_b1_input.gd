extends SceneTree
## demo-08 3D 阶段 B1 真实输入（窗口模式）：飞行中 A/D 横移、相机半跟随无滚转、HUD 横移显示。
## 运行（窗口套件，仅发布前或用户明示时运行——用户 2026-10-04 指令：日常 QA 禁弹窗）：godot --path game -s res://tests/wintest_demo08_3d_b1_input.gd（失败退出码非零）

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


func _frames(n: int) -> void:
	for k in n:
		await physics_frame


func _mouse(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = pos
	ev.global_position = pos
	root.push_input(ev)


func _click(pos: Vector2) -> void:
	_mouse(pos, true)
	await _frames(1)
	_mouse(pos, false)
	await _frames(1)


func _motion(pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	root.push_input(ev)


func _key(keycode: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.pressed = pressed
	root.push_input(ev)


func _btn_center(scene: Node, btn_name: String, parent_hint: String) -> Vector2:
	var parent: Node = scene.get_node_or_null(parent_hint)
	if parent == null:
		return Vector2.ZERO
	var b: Button = parent.get_node_or_null(btn_name)
	if b == null:
		return Vector2.ZERO
	return b.get_global_rect().get_center()


func _run() -> void:
	await process_frame
	_log("demo-08 3D 阶段 B1 真实输入测试开始（窗口模式）")
	var scene: Node = load("res://demo08_3d.tscn").instantiate()
	root.add_child(scene)
	await _frames(3)
	var core: Object = scene.core

	# 起飞：L1 两折 30° 满蓄力
	await _click(_btn_center(scene, "LevelBtn0", "HUD/MenuPanel"))
	var pr: Rect2 = scene._paper_rect()
	await _click(pr.position + pr.size * Vector2(0.92, 0.2))
	await _click(pr.position + pr.size * Vector2(0.92, 0.8))
	await _click(_btn_center(scene, "FoldDoneBtn", "HUD"))
	_motion(Vector2(480.0, 540.0 - 30.0 * 9.0))
	await _frames(1)
	_key(KEY_SPACE, true)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1400:
		await process_frame
	_key(KEY_SPACE, false)
	await _frames(2)
	_check(String(core.state) == "fly", "B1-I1 起飞（angle=%.0f power=%.2f）" % [float(scene.last_throw.angle), float(scene.last_throw.power)])

	# 平飞 30 帧后按住 D 1 秒：横移真实增长
	await _frames(30)
	var x0: float = float(scene.plane_visual.position.x)
	_key(KEY_D, true)
	var t1 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < 1000:
		await process_frame
		var lat: float = float(core.lateral)
		if lat > 1.0:
			pass
	_key(KEY_D, false)
	var x1: float = float(scene.plane_visual.position.x)
	_check(x1 - x0 > 1.0, "B1-I2 按住 D 1 秒横移 %.2f m（世界 X 真实变化）" % (x1 - x0))
	_check(float(core.lateral_vel) > 0.0, "B1-I3 横向速度 %.0f px/s" % float(core.lateral_vel))
	_check(String(scene.status_label.text).contains("横移"), "B1-I4 HUD 显示横移")
	_check(absf(float(scene.cam_rig.rotation.z)) < 1e-9, "B1-I5 相机无滚转（rig rotation.z=0）")
	_check(float(scene.camera.global_position.x) > 0.3, "B1-I6 相机半跟随横移（cam x=%.2f m）" % float(scene.camera.global_position.x))

	# 松开衰减：2.5 秒后 0.5 秒窗口内几乎不再增长
	var t2 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t2 < 2500 and String(core.state) == "fly":
		await process_frame
	var xa: float = float(scene.plane_visual.position.x)
	await _frames(30)
	var xb: float = float(scene.plane_visual.position.x)
	_check(absf(xb - xa) < 0.15, "B1-I7 松开后横移停住（0.5s 窗口 Δ%.3f m）" % absf(xb - xa))

	# 飞行照常结算（转向不破坏通关）
	var guard := 0
	while String(core.state) == "fly" and guard < 1500:
		await process_frame
		await physics_frame
		guard += 1
	_check(String(core.state) == "settle" and core.last_pass and core.flight_distance >= 30.0,
		"B1-I8 转向后照常过关 %.1fm" % core.flight_distance)

	_log("==========================================")
	_log("结果：PASS %d · FAIL %d" % [passes, fails])
	var f := FileAccess.open("user://test_demo08_3d_b1_input_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.flush()
	quit(1 if fails > 0 else 0)
