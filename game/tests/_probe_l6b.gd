extends SceneTree
## L6 探针B：羽毛+按住W 全程弹道
var scene = null
var logf: FileAccess
var frames := 0

func _log(line: String) -> void:
	print(line)
	if logf:
		logf.store_string(line + "\n")
		logf.flush()

func _init() -> void:
	_run()

func _run() -> void:
	logf = FileAccess.open("user://probe_l6b_log.txt", FileAccess.WRITE)
	await process_frame
	scene = load("res://demo02_3d.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene._load_level(5)
	scene.switch_tag(2)
	var launched := false
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 25000:
		frames += 1
		if not launched and scene.ball.linear_velocity.y > 9.0:
			launched = true
			scene.switch_tag(0)
			scene.yaw = -PI / 2
			Input.action_press("p_fwd")
		if frames % 15 == 0 and launched:
			_log("t%d pos=(%.2f,%.2f) v=(%.2f,%.2f) goal=%s" % [frames, scene.ball.position.x, scene.ball.position.y, scene.ball.linear_velocity.x, scene.ball.linear_velocity.y, str(scene.goal_reached)])
		if scene.goal_reached:
			break
		await physics_frame
	_log("END goal=%s" % str(scene.goal_reached))
	logf.flush()
	quit(0)
