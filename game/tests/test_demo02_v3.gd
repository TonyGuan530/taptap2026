extends SceneTree
## demo-02 v3 验证（headless，time_scale 6x）
## ① L1 皮球（弹簧过墙，回归）② L2 石头（砸穿舱门，回归）
## ③ L3 组合链路：弹簧→羽毛空中横漂→石头砸穿脆舱顶
## ④ L3 错误解法：石头硬闯掉坑，自动重置且永不通关
## 结果写入 user://v3log.txt（print 会被 timeout 杀进程丢掉，必须落盘）
## 运行：godot --headless --path game -s res://tests/test_demo02_v3.gd

var scene = null
var logf: FileAccess

func _log(line: String) -> void:
	print(line)
	if logf:
		logf.store_string(line + "\n")
		logf.flush()

func _wait(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < sec * 1000:
		await physics_frame

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
	logf = FileAccess.open("user://v3log.txt", FileAccess.WRITE)
	await process_frame
	Engine.time_scale = 6.0

	# ① L1 皮球弹簧过墙（回归：无输入）
	scene = load("res://demo02_physics.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene._load_level(0)
	scene._on_tag(2)
	var ok := await _until(func(): return scene.goal_reached, 20000)
	_log("① L1 皮球过墙: " + ("PASS" if ok else "FAIL"))
	scene.queue_free()
	await physics_frame

	# ② L2 石头砸舱门（回归：无输入）
	scene = load("res://demo02_physics.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene._load_level(1)
	scene._on_tag(1)
	ok = await _until(func(): return scene.goal_reached, 20000)
	_log("② L2 石头砸舱门: " + ("PASS" if ok else "FAIL"))
	scene.queue_free()
	await physics_frame

	# ③ L3 组合链路：弹簧起飞 → 空中切羽毛 + 按住→横漂 → 舱顶上方切石头砸穿
	scene = load("res://demo02_physics.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene._load_level(2)
	scene._on_tag(0)   # 一开始就用羽毛（缓降落上弹簧）
	var fired := await _until(func(): return scene.ball != null and scene.ball.linear_velocity.y <= -400.0, 20000)
	var falling := await _until(func(): return fired and scene.ball.linear_velocity.y > 0.0, 20000)
	if falling:
		Input.action_press("ui_right")   # 空中横移（v3 新输入）
	var over := await _until(func(): return falling and scene.ball.position.x >= 700.0 and scene.ball.position.y < 235.0, 20000)
	if over:
		Input.action_release("ui_right")
		scene._on_tag(1)   # 舱顶正上方切石头，自由落体砸穿
	ok = await _until(func(): return scene.goal_reached, 20000)
	_log("③ L3 弹簧→羽毛横漂→石头砸舱门: " + ("PASS" if ok else "FAIL") + " (fired=%s over=%s)" % [str(fired), str(over)])
	Input.action_release("ui_right")
	scene.queue_free()
	await physics_frame

	# ④ L3 错误解法：全程石头（不会飞不会漂）→ 掉坑/卡死自动重置，永不通关
	scene = load("res://demo02_physics.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene._load_level(2)
	scene._on_tag(1)
	await _wait(8.0)
	var never: bool = not scene.goal_reached and scene.ball != null
	_log("④ L3 石头硬闯→自动重置不误通关: " + ("PASS" if never else "FAIL") + " (goal_reached=%s)" % str(scene.goal_reached))
	scene.queue_free()

	_log("ALL DONE")
	logf.flush()
	quit()
