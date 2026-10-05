extends SceneTree
## L7 探针：斜抛+切石头破窗全链路弹道

var scene = null
var logf: FileAccess
var frames := 0
var switched := false

func _log(line: String) -> void:
	print(line)
	if logf:
		logf.store_string(line + "\n")
		logf.flush()

func _init() -> void:
	_run()

func _run() -> void:
	logf = FileAccess.open("user://probe_l7_log.txt", FileAccess.WRITE)
	await process_frame
	scene = load("res://demo02_3d.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene._load_level(6)
	scene.switch_tag(2)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 10000 and not scene.goal_reached:
		frames += 1
		if not switched and scene.ball.position.y > 8.0 and scene.ball.linear_velocity.y < 1.0:
			switched = true
			scene.switch_tag(1)
			_log("SWITCH t%d pos=(%.2f,%.2f) v=(%.2f,%.2f)" % [frames, scene.ball.position.x, scene.ball.position.y, scene.ball.linear_velocity.x, scene.ball.linear_velocity.y])
		if frames % 10 == 0:
			_log("t%d pos=(%.2f,%.2f) v=(%.2f,%.2f) broken=%s goal=%s" % [frames, scene.ball.position.x, scene.ball.position.y, scene.ball.linear_velocity.x, scene.ball.linear_velocity.y, str(scene.fragile_broken), str(scene.goal_reached)])
		await physics_frame
	_log("END broken=%s goal=%s" % [str(scene.fragile_broken), str(scene.goal_reached)])
	logf.flush()
	quit(0)
