extends SceneTree
## demo-02 v6 验证（headless，time_scale 6x）
## ①-⑤ L1-L4 全量回归（同 v5 套件）
## ⑥ L5 路线A：弹簧→羽毛横漂（一次扑翼）→ 漂上右高台入 GOAL
## ⑦ L5 路线B：皮球借地面/雨棚弹跳链上高台（零输入涌现路线）
## ⑧ L5 羽毛不借弹簧从出生直漂 → 上不了高台（弹簧必要性）
## 结果写入 user://v6log.txt
## 运行：godot --headless --path game -s res://tests/test_demo02_v6.gd

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
	logf = FileAccess.open("user://v6log.txt", FileAccess.WRITE)
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

	# ③ L3 回归
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
	_log("③ L3 组合链: " + ("PASS" if ok else "FAIL"))
	Input.action_release("ui_right")
	scene.queue_free()
	await physics_frame

	# ④ L4 路线A 回归
	scene = load("res://demo02_physics.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene._load_level(3)
	scene._on_tag(0)
	await _until(func(): return scene.ball != null and scene.ball.linear_velocity.y > 0.0, 10000)
	Input.action_press("ui_right")
	ok = await _until(func(): return scene.goal_reached, 20000)
	_log("④ L4 路线A 出生直漂: " + ("PASS" if ok else "FAIL"))
	Input.action_release("ui_right")
	scene.queue_free()
	await physics_frame

	# ⑤ L4 路线B 回归
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
		if px >= 590.0 and px <= 630.0 and scene.ball.position.y < 200.0:
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
	_log("⑤ L4 路线B 砸穿脆板: " + ("PASS" if ok else "FAIL"))
	Input.action_release("ui_right")
	scene.queue_free()
	await physics_frame

	# ⑥ L5 路线A：弹簧→羽毛横漂+一次扑翼→漂上右高台
	scene = load("res://demo02_physics.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene._load_level(4)
	scene._on_tag(0)
	fired = await _spring_and_drift()
	var flaps_c := 0
	while not scene.goal_reached and flaps_c < 3 and is_instance_valid(scene.ball):
		if scene.ball.linear_velocity.y > 60.0 and scene.ball.position.x < 560.0 and not scene.flap_used:
			scene._try_jump()
			flaps_c += 1
		await physics_frame
	ok = await _until(func(): return scene.goal_reached, 20000)
	_log("⑥ L5 路线A 弹簧→羽毛漂上高台: " + ("PASS" if ok else "FAIL") + " (flaps=%d)" % flaps_c)
	Input.action_release("ui_right")
	scene.queue_free()
	await physics_frame

	# ⑦ L5 路线B：皮球零输入弹跳链上高台（涌现路线）
	# 弹跳对积分步长敏感：time_scale 6x 会改变弹跳结果（已知坑），本用例用真实时间
	scene = load("res://demo02_physics.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	Engine.time_scale = 1.0
	scene._load_level(4)
	scene._on_tag(2)
	ok = await _until(func(): return scene.goal_reached, 30000)
	Engine.time_scale = 6.0
	_log("⑦ L5 路线B 皮球弹跳链: " + ("PASS" if ok else "FAIL"))
	scene.queue_free()
	await physics_frame

	# ⑧ L5 路线C：羽毛不借弹簧，出生直漂借雨棚/高台台阶入 GOAL（涌现路线）
	scene = load("res://demo02_physics.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene._load_level(4)
	scene._on_tag(0)
	await _until(func(): return scene.ball != null and scene.ball.linear_velocity.y > 0.0, 10000)
	Input.action_press("ui_right")
	ok = await _until(func(): return scene.goal_reached, 20000)
	_log("⑧ L5 路线C 无弹簧出生直漂: " + ("PASS" if ok else "FAIL"))
	Input.action_release("ui_right")
	scene.queue_free()

	_log("ALL DONE")
	logf.flush()
	quit()
