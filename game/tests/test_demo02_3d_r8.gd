extends SceneTree
## demo-02 3D L8 robustness gate：跨物理步长/出生扰动验证脆桥双语义
## 判据（监督原则#3）：路线B（砸桥）全配置 broken+goal；路线A（轻过）全配置 !broken+goal。
## 运行：godot --headless --path game -s res://tests/test_demo02_3d_r8.gd

var logf: FileAccess
var fails := 0

func _log(line: String) -> void:
	print(line)
	if logf:
		logf.store_string(line + "\n")
		logf.flush()

func _init() -> void:
	_run()

func _one(ticks: int, mode: String, dx: float, dz: float) -> Dictionary:
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
	var res := {"ticks": ticks, "mode": mode, "dx": dx, "dz": dz, "broken": broken, "goal": goal, "impact_v": impact_v}
	scene.queue_free()
	await physics_frame
	return res

func _run() -> void:
	logf = FileAccess.open("user://v3d_r8_log.txt", FileAccess.WRITE)
	await process_frame
	var configs := [
		{"ticks": 30, "mode": "smash", "dx": 0.0, "dz": 0.0},
		{"ticks": 60, "mode": "smash", "dx": 0.0, "dz": 0.0},
		{"ticks": 120, "mode": "smash", "dx": 0.0, "dz": 0.0},
		{"ticks": 60, "mode": "smash", "dx": 0.25, "dz": 0.15},
		{"ticks": 60, "mode": "smash", "dx": -0.25, "dz": -0.15},
		{"ticks": 30, "mode": "feather", "dx": 0.0, "dz": 0.0},
		{"ticks": 60, "mode": "feather", "dx": 0.0, "dz": 0.0},
		{"ticks": 120, "mode": "feather", "dx": 0.0, "dz": 0.0},
		{"ticks": 60, "mode": "feather", "dx": 0.25, "dz": 0.0},
	]
	var smash_min := 999.0
	for c in configs:
		Engine.physics_ticks_per_second = c.ticks
		var r = await _one(c.ticks, c.mode, c.dx, c.dz)
		if c.mode == "smash":
			smash_min = minf(smash_min, r.impact_v if r.impact_v > 0 else 999.0)
			if not (r.broken and r.goal):
				fails += 1
			_log("R8 smash   ticks=%d dx=%.2f dz=%.2f broken=%s goal=%s impact=%.1f" % [c.ticks, c.dx, c.dz, str(r.broken), str(r.goal), r.impact_v])
		else:
			if r.broken or not r.goal:
				fails += 1
			_log("R8 feather ticks=%d dx=%.2f dz=%.2f broken=%s goal=%s" % [c.ticks, c.dx, c.dz, str(r.broken), str(r.goal)])
		Engine.physics_ticks_per_second = 60
	_log("R8 SUMMARY smash_min=%.1f threshold=11 margin=%.1f fails=%d" % [smash_min, smash_min - 11.0, fails])
	logf.flush()
	quit(1 if fails > 0 else 0)
