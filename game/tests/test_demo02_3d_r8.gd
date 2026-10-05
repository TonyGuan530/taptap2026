extends SceneTree
## demo-02 3D L8 robustness：单场景单进程（跨步长在进程内切换会诱发 physics_frame 停振，由 bash runner 按配置循环）
## 参数：--ticks=N --mode=smash|feather --dx=F --dz=F
## 退出码：0=符合预期（smash 砸桥坠谷 / feather 轻过不碎桥且过关），1=违反
## 运行：godot --headless --path game -s res://tests/test_demo02_3d_r8.gd -- --ticks=60 --mode=smash --dx=0 --dz=0

var logf: FileAccess

func _log(line: String) -> void:
	print(line)
	if logf:
		logf.store_string(line + "\n")
		logf.flush()

func _init() -> void:
	_run()

func _run() -> void:
	var ticks := 60
	var mode := "smash"
	var dx := 0.0
	var dz := 0.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ticks="):
			ticks = int(a.substr(8))
		elif a.begins_with("--mode="):
			mode = a.substr(7)
		elif a.begins_with("--dx="):
			dx = float(a.substr(5))
		elif a.begins_with("--dz="):
			dz = float(a.substr(7))
	logf = FileAccess.open("user://v3d_r8_log.txt", FileAccess.WRITE_READ)
	Engine.physics_ticks_per_second = ticks
	await process_frame
	var scene = load("res://demo02_3d.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene._load_level(7)
	scene.switch_tag(2)
	scene.ball.global_position = Vector3(-8.0 + dx, 1.6 + absf(dx) * 0.5, dz)
	scene.ball.linear_velocity = Vector3.ZERO
	var launched := false
	var broken := false
	var goal := false
	var impact_v := -1.0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 30000 and not goal:
		if not launched and scene.ball != null and scene.ball.linear_velocity.y > 9.0:
			launched = true
			if mode == "feather":
				scene.switch_tag(0)
				scene.yaw = -PI / 2
				Input.action_press("p_fwd")
		if scene.fragile_broken and not broken:
			broken = true
			impact_v = scene.prev_speed
		if scene.goal_reached:
			goal = true
		await physics_frame
	if launched:
		Input.action_release("p_fwd")
	var ok := false
	if mode == "smash":
		ok = broken and goal
	else:
		ok = (not broken) and goal
	_log("R8 ticks=%d mode=%s dx=%.2f dz=%.2f broken=%s goal=%s impact=%.1f ok=%s" % [ticks, mode, dx, dz, str(broken), str(goal), impact_v, str(ok)])
	logf.flush()
	quit(0 if ok else 1)
