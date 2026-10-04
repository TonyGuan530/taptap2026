extends SceneTree
## DEMO2 3D 阶段B 验证：LEVELS 框架 + L1/L2/L3 三房间（真实时间 time_scale=1）
## ① L1 皮球+W 越墙入 GOAL ② L1 石头撞墙不误通关 ③ L2 横漂对准+顶点转石头砸脆板
## ④ L3 组合：弹簧→顶点转羽毛→扑翼+W 跨峡谷入远端 GOAL ⑤ L3 石头直走掉峡谷不误通关
## 结果写入 user://v3d_b_log.txt；FAIL → 非零退出码

var scene = null
var logf: FileAccess
var fails := 0

func _log(line: String) -> void:
	print(line)
	if logf:
		logf.store_string(line + "\n")
		logf.flush()

func _until(cond: Callable, timeout_s: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout_s * 1000:
		if cond.call():
			return true
		await physics_frame
	return false

func _check(name: String, ok: bool) -> void:
	if not ok:
		fails += 1
	_log(name + ": " + ("PASS" if ok else "FAIL"))

func _wait_frames(n: int) -> void:
	for i in n:
		await physics_frame

func _new_scene(idx: int) -> void:
	scene = load("res://demo02_3d.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene._load_level(idx)

func _init() -> void:
	_run()

func _run() -> void:
	logf = FileAccess.open("user://v3d_b_log.txt", FileAccess.WRITE)
	await process_frame

	# ① L1：皮球+弹簧+按住 W 越墙入 GOAL
	await _new_scene(0)
	scene.switch_tag(2)
	scene.yaw = -PI / 2   # 面朝 +X
	Input.action_press("p_fwd")
	var frames := 0
	while not scene.goal_reached and frames < 1500:
		frames += 1
		if frames % 300 == 0:
			_log("① tick=%d pos=%s vel=%s goal=%s" % [frames, str(scene.ball.global_position), str(scene.ball.linear_velocity), str(scene.goal_reached)])
		await physics_frame
	Input.action_release("p_fwd")
	var ok: bool = scene.goal_reached
	_check("① L1 皮球越墙入 GOAL", ok)
	_log("① frames=%d" % frames)
	scene.queue_free()
	await physics_frame

	# ② L1 石头：撞墙卡住，不误通关
	await _new_scene(0)
	scene.switch_tag(1)
	var t0 := Time.get_ticks_msec()
	while not scene.goal_reached and Time.get_ticks_msec() - t0 < 10000:
		await physics_frame
	_check("② L1 石头撞墙不误通关", not scene.goal_reached)
	scene.queue_free()
	await physics_frame

	# ③ L2：弹簧上抛（羽毛上升期向左横漂对准脆板），顶点转石头砸穿入 GOAL
	await _new_scene(1)
	scene.switch_tag(0)
	var launched: bool = await _until(func(): return scene.ball != null and scene.ball.linear_velocity.y > 9.0, 10000)
	Input.action_press("p_left")
	var aligned: bool = await _until(func(): return scene.ball.position.x <= -7.4, 8000)
	Input.action_release("p_left")
	_log("③ aligned=%s vy=%.1f y=%.1f" % [str(aligned), scene.ball.linear_velocity.y, scene.ball.position.y])
	# 顶点附近（上升转下落）转石头，砸向下方脆板
	await _until(func(): return scene.ball != null and scene.ball.linear_velocity.y > -2.0 and scene.ball.linear_velocity.y < 2.0, 8000)
	scene.switch_tag(1)
	ok = await _until(func(): return scene.goal_reached, 20000)
	_check("③ L2 转石头砸穿脆板", ok and scene.fragile_broken)
	_log("③ aligned=%s" % str(aligned))
	scene.queue_free()
	await physics_frame

	# ④ L3 组合：弹簧→顶点转羽毛→扑翼+按住 W 跨峡谷→远端 GOAL
	await _new_scene(2)
	scene.switch_tag(2)
	_teleport_pad()
	launched = await _until(func(): return scene.ball != null and scene.ball.linear_velocity.y > 9.0, 10000)
	# 顶点转羽毛（缓慢下落 + W 横移跨峡谷）
	await _until(func(): return scene.ball != null and scene.ball.linear_velocity.y > -2.0 and scene.ball.linear_velocity.y < 2.0, 8000)
	scene.switch_tag(0)
	scene.yaw = -PI / 2   # 面朝 +X
	Input.action_press("p_fwd")
	var flaps := 0
	var released := false
	while not scene.goal_reached and flaps < 4:
		if scene.ball.position.x >= 9.5 and not released:
			released = true
			Input.action_release("p_fwd")   # 出峡谷即松 W，垂直落入远端 GOAL 带
		if scene.ball.linear_velocity.y < -1.0 and not scene.flap_used:
			scene.try_flap()
			flaps += 1
		await physics_frame
	Input.action_release("p_fwd")
	var ok4: bool = await _until(func(): return scene.goal_reached, 20000)
	_check("④ L3 弹簧→羽毛跨峡谷入远端 GOAL", ok4)
	_log("④ released=%s flaps=%d pos=%s" % [str(released), str(flaps), str(scene.ball.global_position)])
	scene.queue_free()
	await physics_frame

	# ⑤ L3 石头直走失败对照：掉峡谷，不误通关
	await _new_scene(2)
	scene.switch_tag(1)
	t0 = Time.get_ticks_msec()
	while not scene.goal_reached and Time.get_ticks_msec() - t0 < 12000:
		await physics_frame
	_check("⑤ L3 石头直走不误通关", not scene.goal_reached)
	scene.queue_free()

	_log("ALL DONE fails=%d" % fails)
	logf.flush()
	quit(1 if fails > 0 else 0)

func _teleport_pad() -> void:
	scene.ball.global_position = Vector3(-4.5, 0.6, 0)
	scene.ball.linear_velocity = Vector3.ZERO
