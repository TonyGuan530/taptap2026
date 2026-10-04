extends SceneTree
## L3 羽毛弧线实测探针：记录 (x,y) 轨迹 → 依据实测放置高台/GOAL

var scene = null
var logf: FileAccess

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

func _init() -> void:
	_run()

func _run() -> void:
	logf = FileAccess.open("user://v3d_arc.txt", FileAccess.WRITE)
	await process_frame
	scene = load("res://demo02_3d.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene._load_level(2)
	scene.switch_tag(2)
	scene.ball.global_position = Vector3(-4.5, 0.6, 0)
	scene.ball.linear_velocity = Vector3.ZERO
	var launched: bool = await _until(func(): return scene.ball != null and scene.ball.linear_velocity.y > 9.0, 10000)
	_log("launched=" + str(launched))
	# 顶点转羽毛
	await _until(func(): return scene.ball != null and scene.ball.linear_velocity.y > -2.0 and scene.ball.linear_velocity.y < 2.0, 8000)
	scene.switch_tag(0)
	Input.action_press("p_fwd")
	var frames := 0
	while frames < 60 * 12:
		frames += 1
		if scene.ball == null:
			break
		if frames % 15 == 0:
			_log("arc x=%.2f y=%.2f z=%.2f vy=%.2f" % [scene.ball.position.x, scene.ball.position.y, scene.ball.position.z, scene.ball.linear_velocity.y])
		if scene.ball.position.y < 0.0:
			_log("FELL below floor at x=%.2f" % scene.ball.position.x)
			break
		await physics_frame
	Input.action_release("p_fwd")
	_log("ARC DONE")
	logf.flush()
	quit(0)
