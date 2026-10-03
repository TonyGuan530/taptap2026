extends SceneTree
## demo-02 v5 验证（headless，time_scale 6x）
## ① L1 回归 ② L2 回归+撞板速度反馈断言 ③ L3 组合链回归+路线行断言
## ④ L4 路线A 回归 ⑤ L4 路线B + telemetry 断言（弹簧/切换≥2/路线行）⑥ L4 错误解法不误通关
## 结果写入 user://v5log.txt（print 会被 timeout 杀进程丢掉，必须落盘）
## 运行：godot --headless --path game -s res://tests/test_demo02_v5.gd

var scene = null
var logf: FileAccess

func _log(line: String) -> void:
	print(line)
	if logf:
		logf.store_string(line + "\n")
		logf.flush()

func _until(cond: Callable, timeout_ms: int) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout_ms:
		if cond.call():
			return true
		await physics_frame
	return false

func _spring_and_drift() -> bool:
	var fired: bool = await _until(func(): return scene.ball != null and scene.ball.linear_velocity.y <= -400.0, 20000)
	if not fired:
		return false
	await _until(func(): return scene.ball.linear_velocity.y > 0.0, 20000)
	Input.action_press("ui_right")
	return true

func _init() -> void:
	_run()

func _run() -> void:
	logf = FileAccess.open("user://v5log.txt", FileAccess.WRITE)
	await process_frame
	Engine.time_scale = 6.0

	# ① L1 回归
	scene = load("res://demo02_physics.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene._load_level(0)
	scene._on_tag(2)
	var ok: bool = await _until(func(): return scene.goal_reached, 20000)
	_log("① L1 皮球过墙: " + ("PASS" if ok else "FAIL"))
	scene.queue_free()
	await physics_frame

	# ② L2 回归 + 撞板速度反馈断言
	scene = load("res://demo02_physics.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene._load_level(1)
	scene._on_tag(1)
	ok = await _until(func(): return scene.goal_reached, 20000)
	var hit_feedback: bool = scene.tel_hits.size() > 0 and scene.hint.contains("≥")
	_log("② L2 石头砸舱门: " + ("PASS" if ok else "FAIL") + "｜撞板反馈: " + ("PASS" if hit_feedback else "FAIL") + " (%s)" % str(scene.tel_hits))
	scene.queue_free()
	await physics_frame

	# ③ L3 组合链回归 + 路线行断言
	scene = load("res://demo02_physics.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene._load_level(2)
	scene._on_tag(0)
	var fired: bool = await _spring_and_drift()
	var flaps := 0
	while not scene.goal_reached and flaps < 3:
		if scene.ball.position.x >= 720.0 and scene.ball.position.y < 230.0:
			break
		if scene.ball.linear_velocity.y > 80.0 and not scene.flap_used:
			scene._try_jump()
			flaps += 1
		await physics_frame
	var over: bool = scene.ball.position.x >= 720.0 and scene.ball.position.y < 230.0
	if over:
		Input.action_release("ui_right")
		scene._on_tag(1)
	ok = await _until(func(): return scene.goal_reached, 20000)
	var route_ok: bool = scene.route_line.contains("石头") and scene.route_line.contains("借弹簧")
	_log("③ L3 弹簧→羽毛→石头: " + ("PASS" if ok else "FAIL") + "｜路线行: " + ("PASS" if route_ok else "FAIL") + " (%s)" % scene.route_line)
	Input.action_release("ui_right")
	scene.queue_free()
	await physics_frame

	# ④ L4 路线A：羽毛出生直漂（不用弹簧）
	scene = load("res://demo02_physics.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene._load_level(3)
	scene._on_tag(0)
	await _until(func(): return scene.ball != null and scene.ball.linear_velocity.y > 0.0, 10000)
	Input.action_press("ui_right")
	ok = await _until(func(): return scene.goal_reached, 20000)
	_log("④ L4 路线A 羽毛出生直漂: " + ("PASS" if ok else "FAIL"))
	Input.action_release("ui_right")
	scene.queue_free()
	await physics_frame

	# ⑤ L4 路线B + telemetry 断言（借弹簧/切换≥2/路线行）
	scene = load("res://demo02_physics.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene._load_level(3)
	scene._on_tag(0)
	fired = await _spring_and_drift()
	var flaps_b := 0
	var over_b := false
	while not scene.goal_reached and flaps_b < 3 and is_instance_valid(scene.ball):
		var px: float = scene.ball.position.x
		var py: float = scene.ball.position.y
		if px >= 590.0 and px <= 630.0 and py < 200.0:
			over_b = true
			break
		if scene.ball.linear_velocity.y > 60.0 and px < 560.0 and not scene.flap_used:
			scene._try_jump()
			flaps_b += 1
		await physics_frame
	if over_b:
		Input.action_release("ui_right")
		scene._on_tag(1)
	ok = await _until(func(): return scene.goal_reached, 20000)
	var tel_ok: bool = ok and scene.tel_spring and scene.tel_switches.size() >= 1 and scene.tel_switches[0].begins_with("石头") and scene.route_line.contains("路线#") and scene.route_line.contains("[high_window]")
	_log("⑤ L4 路线B 砸穿脆板: " + ("PASS" if ok else "FAIL") + "｜telemetry: " + ("PASS" if tel_ok else "FAIL") + " (%s)" % scene.route_line)
	Input.action_release("ui_right")
	scene.queue_free()
	await physics_frame

	# ⑥ L4 错误解法：全程石头掉坑，不误通关
	scene = load("res://demo02_physics.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene._load_level(3)
	scene._on_tag(1)
	var t0 := Time.get_ticks_msec()
	while not scene.goal_reached and Time.get_ticks_msec() - t0 < 8000:
		await physics_frame
	var never: bool = not scene.goal_reached and scene.ball != null
	_log("⑥ L4 石头硬闯不误通关: " + ("PASS" if never else "FAIL"))
	scene.queue_free()

	_log("ALL DONE")
	logf.flush()
	quit()
