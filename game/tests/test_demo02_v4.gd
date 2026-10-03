extends SceneTree
## demo-02 v4 验证（headless，time_scale 6x）
## ① L1 皮球（弹簧过墙，回归）② L2 石头（砸穿舱门，回归）
## ③ L3 组合链（扑翼已削为滞空单次轻修正后的回归）
## ④ L4 路线A：弹簧→羽毛横漂→右敞口入舱（全程不用石头）
## ⑤ L4 路线B：弹簧→羽毛→脆板上方切石头砸入
## ⑥ L4 错误解法：石头硬闯掉坑，自动重置且永不通关
## 结果写入 user://v4log.txt（print 会被 timeout 杀进程丢掉，必须落盘）
## 运行：godot --headless --path game -s res://tests/test_demo02_v4.gd

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

func _spring_and_drift(scene_ref) -> bool:
	# 弹簧点火 → 上升转下落 → 按住→横漂，掉高度时扑翼（游戏侧限制滞空一次）
	var fired: bool = await _until(func(): return scene.ball != null and scene.ball.linear_velocity.y <= -400.0, 20000)
	if not fired:
		_log("!! spring NOT fired")
		return false
	var falling: bool = await _until(func(): return scene.ball.linear_velocity.y > 0.0, 20000)
	_log("!! drift start: falling=%s pressed_before=%s" % [str(falling), str(Input.is_action_pressed("ui_right"))])
	Input.action_press("ui_right")
	_log("!! drift press done: pressed_after=%s" % str(Input.is_action_pressed("ui_right")))
	return falling

func _init() -> void:
	_run()

func _run() -> void:
	logf = FileAccess.open("user://v4log.txt", FileAccess.WRITE)
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

	# ② L2 回归
	scene = load("res://demo02_physics.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene._load_level(1)
	scene._on_tag(1)
	ok = await _until(func(): return scene.goal_reached, 20000)
	_log("② L2 石头砸舱门: " + ("PASS" if ok else "FAIL"))
	scene.queue_free()
	await physics_frame

	# ③ L3 组合链（弱化扑翼后回归）
	_log("-- case 3 start")
	scene = load("res://demo02_physics.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene._load_level(2)
	scene._on_tag(0)
	await _spring_and_drift(scene)
	var flaps := 0
	while not scene.goal_reached and flaps < 3:
		if scene.ball.position.x >= 720.0 and scene.ball.position.y < 230.0:
			break
		if scene.ball.linear_velocity.y > 80.0:
			scene._try_jump()
			flaps += 1
		await physics_frame
	var over: bool = scene.ball.position.x >= 720.0 and scene.ball.position.y < 230.0
	if over:
		Input.action_release("ui_right")
		scene._on_tag(1)
	ok = await _until(func(): return scene.goal_reached, 20000)
	_log("③ L3 弹簧→羽毛横漂→石头砸舱门: " + ("PASS" if ok else "FAIL") + " (over=%s flaps=%d)" % [str(over), flaps])
	Input.action_release("ui_right")
	scene.queue_free()
	await physics_frame

	# ④ L4 路线A：弹簧→羽毛→右敞口入舱（不切石头，代码只查 GOAL）
	_log("-- case 4 start")
	scene = load("res://demo02_physics.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene._load_level(3)
	scene._on_tag(0)
	await _spring_and_drift(scene)
	var flaps_a := 0
	var guard := 0
	while not scene.goal_reached and flaps_a < 3 and is_instance_valid(scene.ball):
		guard += 1
		if guard > 60 * 30:
			_log("-- case 4 GUARD EXIT (pos=%s vel=%s)" % [str(scene.ball.position), str(scene.ball.linear_velocity)])
			break
		if guard % 300 == 0:
			_log("-- case 4 t=%d pos=(%d,%d) vel=(%d,%d) goal=%s input_r=%s axis=%s" % [guard, int(scene.ball.position.x), int(scene.ball.position.y), int(scene.ball.linear_velocity.x), int(scene.ball.linear_velocity.y), str(scene.goal_reached), str(Input.is_action_pressed("ui_right")), str(Input.get_axis("ui_left", "ui_right"))])
		if scene.ball.linear_velocity.y > 140.0 and scene.ball.position.x < 700.0:
			scene._try_jump()
			flaps_a += 1
		await physics_frame
	_log("-- case 4 loop done (goal=%s flaps=%d)" % [str(scene.goal_reached), flaps_a])
	ok = await _until(func(): return scene.goal_reached, 20000)
	_log("④ L4 路线A 羽毛漂入右敞口: " + ("PASS" if ok else "FAIL") + " (flaps=%d)" % flaps_a)
	Input.action_release("ui_right")
	scene.queue_free()
	await physics_frame

	# ⑤ L4 路线B：弹簧→羽毛→（扑翼抬升）脆板上方(640..740, y<215)切石头砸穿
	_log("-- case 5 start")
	scene = load("res://demo02_physics.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene._load_level(3)
	scene._on_tag(0)
	await _spring_and_drift(scene)
	var flaps_b := 0
	var over_b := false
	while not scene.goal_reached and flaps_b < 3 and is_instance_valid(scene.ball):
		var px: float = scene.ball.position.x
		var py: float = scene.ball.position.y
		if px >= 640.0 and px <= 740.0 and py < 215.0:
			over_b = true
			break
		if scene.ball.linear_velocity.y > 60.0 and px < 620.0:
			scene._try_jump()
			flaps_b += 1
		await physics_frame
	_log("-- case 5 loop done (goal=%s over=%s flaps=%d)" % [str(scene.goal_reached), str(over_b), flaps_b])
	if over_b:
		Input.action_release("ui_right")
		scene._on_tag(1)
	ok = await _until(func(): return scene.goal_reached, 20000)
	_log("⑤ L4 路线B 砸穿脆板入舱: " + ("PASS" if ok else "FAIL") + " (over=%s flaps=%d)" % [str(over_b), flaps_b])
	Input.action_release("ui_right")
	scene.queue_free()
	await physics_frame

	# ⑥ L4 错误解法：全程石头（弹簧弧线不够高）→ 掉坑自动重置，永不通关
	scene = load("res://demo02_physics.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene._load_level(3)
	scene._on_tag(1)
	var t0 := Time.get_ticks_msec()
	while not scene.goal_reached and Time.get_ticks_msec() - t0 < 8000:
		await physics_frame
	var never: bool = not scene.goal_reached and scene.ball != null
	_log("⑥ L4 石头硬闯→自动重置不误通关: " + ("PASS" if never else "FAIL") + " (goal_reached=%s)" % str(scene.goal_reached))
	scene.queue_free()

	_log("ALL DONE")
	logf.flush()
	quit()
