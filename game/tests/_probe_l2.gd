extends SceneTree
## 只跑 b 套件 ③（L2 砸板），每个 await 后打心跳，定位静默卡死点

var scene = null
var logf: FileAccess

func _log(line: String) -> void:
	print(line)
	if logf:
		logf.store_string(line + "\n")
		logf.flush()

func _until(tag: String, cond: Callable, timeout_s: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout_s * 1000:
		if cond.call():
			_log("%s => true @%.1fs" % [tag, (Time.get_ticks_msec() - t0) / 1000.0])
			return true
		await physics_frame
	_log("%s => TIMEOUT %.0fs" % [tag, timeout_s])
	return false

func _init() -> void:
	_run()

func _run() -> void:
	logf = FileAccess.open("user://probe_l2_log.txt", FileAccess.WRITE)
	await process_frame
	_log("A: frame alive")
	scene = load("res://demo02_3d.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	_log("B: scene added")
	scene._load_level(1)
	scene.switch_tag(0)
	_log("C: tag=feather")
	var launched: bool = await _until("D_launch", func(): return scene.ball != null and scene.ball.linear_velocity.y > 9.0, 10.0)
	_log("E: launched=%s vy=%.1f" % [str(launched), scene.ball.linear_velocity.y if scene.ball != null else -999.0])
	Input.action_press("p_left")
	var aligned: bool = await _until("F_align", func(): return scene.ball != null and scene.ball.position.x <= -7.4, 8.0)
	Input.action_release("p_left")
	_log("G: aligned=%s x=%.2f vy=%.1f y=%.1f" % [str(aligned), scene.ball.position.x, scene.ball.linear_velocity.y, scene.ball.position.y])
	await _until("H_apex", func(): return scene.ball != null and scene.ball.linear_velocity.y > -2.0 and scene.ball.linear_velocity.y < 2.0, 8.0)
	_log("I: pre-switch vy=%.1f y=%.1f" % [scene.ball.linear_velocity.y, scene.ball.position.y])
	scene.switch_tag(1)
	await physics_frame
	_log("J: switched stone vy=%.1f" % scene.ball.linear_velocity.y)
	var ok: bool = await _until("K_goal", func(): return scene.goal_reached, 20.0)
	_log("L: goal=%s broken=%s" % [str(scene.goal_reached), str(scene.fragile_broken)])
	_log("PROBE DONE ok=%s" % str(ok))
	logf.flush()
	quit(0)
