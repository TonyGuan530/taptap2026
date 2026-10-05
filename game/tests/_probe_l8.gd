extends SceneTree
## L8 探针：羽毛刹车低压桥下滑翔全轨迹

var scene = null
var logf: FileAccess
var frames := 0
var braked := false
var gliding := false

func _log(line: String) -> void:
	print(line)
	if logf:
		logf.store_string(line + "\n")
		logf.flush()

func _init() -> void:
	_run()

func _run() -> void:
	logf = FileAccess.open("user://probe_l8_log.txt", FileAccess.WRITE)
	await process_frame
	scene = load("res://demo02_3d.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene._load_level(7)
	scene.switch_tag(2)
	var launched := false
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 20000 and not scene.goal_reached:
		frames += 1
		if not launched and scene.ball.linear_velocity.y > 9.0:
			launched = true
			scene.switch_tag(0)
			scene.yaw = -PI / 2
			Input.action_press("p_left")
			t0 = Time.get_ticks_msec()   # 重置计时：刹车 1.8s 从切羽时刻起算
		if launched and not braked and Time.get_ticks_msec() - t0 > 1800:
			braked = true
			Input.action_release("p_left")
			_log("BRAKE-END t%d pos=(%.2f,%.2f) v=(%.2f,%.2f)" % [frames, scene.ball.position.x, scene.ball.position.y, scene.ball.linear_velocity.x, scene.ball.linear_velocity.y])
		if braked and not gliding and scene.ball.position.y < 2.2 and scene.ball.position.x < -1.0:
			gliding = true
			Input.action_press("p_fwd")
			_log("GLIDE-START t%d pos=(%.2f,%.2f)" % [frames, scene.ball.position.x, scene.ball.position.y])
		if frames % 15 == 0 and launched:
			_log("t%d pos=(%.2f,%.2f) v=(%.2f,%.2f) braked=%s glide=%s" % [frames, scene.ball.position.x, scene.ball.position.y, scene.ball.linear_velocity.x, scene.ball.linear_velocity.y, str(braked), str(gliding)])
		await physics_frame
	_log("END goal=%s broken=%s" % [str(scene.goal_reached), str(scene.fragile_broken)])
	logf.flush()
	quit(0)
