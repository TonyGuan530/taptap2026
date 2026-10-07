extends SceneTree
## demo-02 3D L7 robustness：单场景单进程（跨步长在进程内切换会诱发 physics_frame 停振，由 bash runner 按配置循环）
## 参数：--ticks=N --mode=stone|ball --dx=F --dz=F
## 退出码：0=符合预期（stone 破窗入室 / ball 均不发生），1=违反
## 运行：godot --headless --path game -s res://tests/test_demo02_3d_r7.gd -- --ticks=60 --mode=stone --dx=0 --dz=0

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
	var mode := "stone"
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
	logf = FileAccess.open("user://v3d_r7_log.txt", FileAccess.WRITE_READ)
	Engine.physics_ticks_per_second = ticks
	await process_frame
	var scene = load("res://demo02_3d.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene._load_level(6)
	scene.switch_tag(2)
	scene.ball.global_position = Vector3(-8.0 + dx, 1.6 + absf(dx) * 0.5, dz)
	scene.ball.linear_velocity = Vector3.ZERO
	var launched := false
	var broken := false
	var goal := false
	var impact_v := -1.0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 12000 and not goal:
		if not launched and scene.ball != null and scene.ball.linear_velocity.y > 9.0:
			launched = true
		if launched and mode == "stone" and scene.ball.position.y > 6.0 and scene.ball.linear_velocity.y < 2.0 and scene.tag_idx != 1:
			scene.switch_tag(1)   # 顶点切石头
		if launched and not broken and scene.ball.position.y < 5.5 and scene.ball.position.y > 0.5 and scene.ball.position.x > 0.4 and scene.ball.position.x < 2.2:
			impact_v = scene.ball.linear_velocity.length()
		if scene.fragile_broken and not broken:
			broken = true
			impact_v = scene.prev_speed
		if scene.goal_reached:
			goal = true
		await physics_frame
	var ok := false
	if mode == "stone":
		ok = broken and goal
	else:
		ok = (not broken) and (not goal)
	_log("R7 ticks=%d mode=%s dx=%.2f dz=%.2f broken=%s goal=%s impact=%.1f ok=%s" % [ticks, mode, dx, dz, str(broken), str(goal), impact_v, str(ok)])
	logf.flush()
	quit(0 if ok else 1)
