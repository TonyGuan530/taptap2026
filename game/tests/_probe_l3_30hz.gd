extends SceneTree
## L3 探针：30Hz（电影模式步长）下跑驱动同款 L3 编排，打印卡点

var scene = null
var logf: FileAccess
var frames := 0
var sub := 0
var flaps := 0
var released := false

func _log(line: String) -> void:
	print(line)
	if logf:
		logf.store_string(line + "\n")
		logf.flush()

func _init() -> void:
	_run()

func _run() -> void:
	logf = FileAccess.open("user://probe_l3hz_log.txt", FileAccess.WRITE)
	Engine.physics_ticks_per_second = 30
	await process_frame
	scene = load("res://demo02_3d.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene._load_level(2)
	scene.switch_tag(2)
	scene.ball.global_position = Vector3(-4.5, 0.6, 0)
	scene.ball.linear_velocity = Vector3.ZERO
	scene.yaw = -PI / 2
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 30000 and not scene.goal_reached:
		frames += 1
		match sub:
			0:
				if scene.ball.linear_velocity.y > 9.0:
					_log("S1 t%d vy=%.1f" % [frames, scene.ball.linear_velocity.y])
					sub = 1
			1:
				if scene.ball.linear_velocity.y > -2.0 and scene.ball.linear_velocity.y < 2.0:
					scene.switch_tag(0)
					Input.action_press("p_fwd")
					_log("S2 t%d switch feather pos=(%.2f,%.2f)" % [frames, scene.ball.position.x, scene.ball.position.y])
					sub = 2
			2:
				if scene.ball.position.x >= 8.0 and not released:
					released = true
					Input.action_release("p_fwd")
					scene.switch_tag(1)
					_log("S3 t%d release pos=(%.2f,%.2f)" % [frames, scene.ball.position.x, scene.ball.position.y])
				if scene.ball.linear_velocity.y < -1.0 and not scene.flap_used:
					scene.try_flap()
					flaps += 1
		if frames % 20 == 0:
			_log("t%d pos=(%.2f,%.2f) v=(%.2f,%.2f) sub=%d flaps=%d" % [frames, scene.ball.position.x, scene.ball.position.y, scene.ball.linear_velocity.x, scene.ball.linear_velocity.y, sub, flaps])
		await physics_frame
	_log("END goal=%s flaps=%d" % [str(scene.goal_reached), str(flaps)])
	logf.flush()
	quit(0)
