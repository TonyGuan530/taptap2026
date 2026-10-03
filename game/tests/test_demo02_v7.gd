extends SceneTree
## demo-02 v7 验证（headless）
## ① L5 路线B 皮球零输入弹跳链（真实时间）：通关 + idle_completion=true
## ② L5 路线A 弹簧羽毛横漂+扑翼：通关 + idle_completion=false
## ③ L5 关名含「自由实验」定位语义（debug 可见）
## ④ L2 快速回归
## 结果写入 user://v7log.txt
## 运行：godot --headless --path game -s res://tests/test_demo02_v7.gd

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

func _init() -> void:
	_run()

func _run() -> void:
	logf = FileAccess.open("user://v7log.txt", FileAccess.WRITE)
	await process_frame

	# ① L5 路线B：皮球零输入（真实时间，弹跳积分敏感）
	scene = load("res://demo02_physics.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene._load_level(4)
	scene._on_tag(2)
	var ok: bool = await _until(func(): return scene.goal_reached, 30000)
	var idle_ok: bool = ok and scene.route_line.contains("idle_completion")
	_log("① L5 路线B 零输入弹跳: " + ("PASS" if ok else "FAIL") + "｜idle_completion=true: " + ("PASS" if idle_ok else "FAIL") + " (%s)" % scene.route_line)
	scene.queue_free()
	await physics_frame

	# ② L5 路线A：弹簧→羽毛横漂+一次扑翼（真实时间，保证与①同积分条件）
	Engine.time_scale = 1.0
	scene = load("res://demo02_physics.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene._load_level(4)
	scene._on_tag(0)
	var fired: bool = await _until(func(): return scene.ball != null and scene.ball.linear_velocity.y <= -400.0, 20000)
	if fired:
		await _until(func(): return scene.ball.linear_velocity.y > 0.0, 20000)
		Input.action_press("ui_right")
	var flaps := 0
	while not scene.goal_reached and flaps < 3 and is_instance_valid(scene.ball):
		if scene.ball.linear_velocity.y > 60.0 and scene.ball.position.x < 560.0 and not scene.flap_used:
			scene._try_jump()
			flaps += 1
		await physics_frame
	ok = await _until(func(): return scene.goal_reached, 30000)
	var not_idle: bool = ok and not scene.route_line.contains("idle_completion")
	_log("② L5 路线A 弹簧羽毛: " + ("PASS" if ok else "FAIL") + "｜idle_completion=false: " + ("PASS" if not_idle else "FAIL") + " (%s)" % scene.route_line)
	Input.action_release("ui_right")
	scene.queue_free()
	await physics_frame

	# ③ L5 关名定位语义（debug 显示含参考解法，关名恒显）
	scene = load("res://demo02_physics.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene._load_level(4)
	var name_ok: bool = scene.level_label.text.contains("自由实验")
	_log("③ L5 自由实验定位语义: " + ("PASS" if name_ok else "FAIL") + " (%s)" % scene.level_label.text)
	scene.queue_free()
	await physics_frame

	# ④ L2 快速回归（真实时间）
	scene = load("res://demo02_physics.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene._load_level(1)
	scene._on_tag(1)
	ok = await _until(func(): return scene.goal_reached, 30000)
	_log("④ L2 石头砸舱门回归: " + ("PASS" if ok else "FAIL"))
	scene.queue_free()

	_log("ALL DONE")
	logf.flush()
	quit()
