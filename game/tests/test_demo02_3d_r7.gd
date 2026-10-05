extends SceneTree
## demo-02 3D L7 robustness gate：跨物理步长/出生扰动验证天窗阈值判别力
## 判据（监督 2026-10-05）：石头破窗在所有配置下成立；皮球自然弹道在所有配置下明显低于阈 14。
## 运行：godot --headless --path game -s res://tests/test_demo02_3d_r7.gd

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
			if mode == "stone":
				scene.switch_tag(2)  # 占位：真实切换在顶点条件
		if launched and mode == "stone" and scene.ball.position.y > 6.0 and scene.ball.linear_velocity.y < 2.0 and scene.tag_idx != 1:
			scene.switch_tag(1)   # 顶点切石头
		if launched and not broken and scene.ball.position.y < 5.5 and scene.ball.position.y > 0.5 and scene.ball.position.x > 0.4 and scene.ball.position.x < 2.2:
			impact_v = scene.ball.linear_velocity.length()   # 天窗面附近速度
		if scene.fragile_broken and not broken:
			broken = true
			impact_v = scene.prev_speed   # 破窗瞬间冲击
		if scene.goal_reached:
			goal = true
		await physics_frame
	var res := {"ticks": ticks, "mode": mode, "dx": dx, "dz": dz, "broken": broken, "goal": goal, "impact_v": impact_v}
	scene.queue_free()
	await physics_frame
	return res

func _run() -> void:
	logf = FileAccess.open("user://v3d_r7_log.txt", FileAccess.WRITE)
	await process_frame
	var configs := [
		{"ticks": 30, "mode": "stone", "dx": 0.0, "dz": 0.0},
		{"ticks": 60, "mode": "stone", "dx": 0.0, "dz": 0.0},
		{"ticks": 120, "mode": "stone", "dx": 0.0, "dz": 0.0},
		{"ticks": 60, "mode": "stone", "dx": 0.25, "dz": 0.15},
		{"ticks": 60, "mode": "stone", "dx": -0.25, "dz": -0.15},
		{"ticks": 30, "mode": "ball", "dx": 0.0, "dz": 0.0},
		{"ticks": 60, "mode": "ball", "dx": 0.0, "dz": 0.0},
		{"ticks": 120, "mode": "ball", "dx": 0.0, "dz": 0.0},
		{"ticks": 60, "mode": "ball", "dx": 0.25, "dz": 0.0},
	]
	var stone_min := 999.0
	var ball_max := -1.0
	for c in configs:
		Engine.physics_ticks_per_second = c.ticks
		var r = await _one(c.ticks, c.mode, c.dx, c.dz)
		if c.mode == "stone":
			stone_min = minf(stone_min, r.impact_v if r.impact_v > 0 else 999.0)
			if not (r.broken and r.goal):
				fails += 1
			_log("R7 stone ticks=%d dx=%.2f dz=%.2f broken=%s goal=%s impact=%.1f" % [c.ticks, c.dx, c.dz, str(r.broken), str(r.goal), r.impact_v])
		else:
			ball_max = maxf(ball_max, r.impact_v)
			if r.broken or r.goal:
				fails += 1
			_log("R7 ball  ticks=%d dx=%.2f dz=%.2f broken=%s goal=%s impact=%.1f" % [c.ticks, c.dx, c.dz, str(r.broken), str(r.goal), r.impact_v])
		Engine.physics_ticks_per_second = 60
	_log("R7 SUMMARY stone_min=%.1f ball_max=%.1f threshold=14 margin_ball=%.1f fails=%d" % [stone_min, ball_max, 14.0 - ball_max, fails])
	logf.flush()
	quit(1 if fails > 0 else 0)
