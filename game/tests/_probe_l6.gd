extends SceneTree
## L6 抛接峡谷弹道探针：验证 石头直线弹道落点 / 羽毛自然漂移落点（调浮空弹板接引用）

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
	logf = FileAccess.open("user://probe_l6_log.txt", FileAccess.WRITE)
	await process_frame
	# 阶段1：石头无输入直线弹道（预期错过浮板 y5.3-5.7 带、落在 x≈10.5 落谷）
	scene = load("res://demo02_3d.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene._load_level(5)
	scene.switch_tag(1)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 9000:
		frames += 1
		if frames % 20 == 0:
			_log("S t%d pos=(%.2f,%.2f) v=(%.2f,%.2f)" % [frames, scene.ball.position.x, scene.ball.position.y, scene.ball.linear_velocity.x, scene.ball.linear_velocity.y])
		await physics_frame
	_log("S END goal=%s" % str(scene.goal_reached))
	scene.queue_free()
	await physics_frame
	# 阶段2：羽毛起飞即切、无输入自然漂移（看 x 落点是否接近浮板 x4..6）
	frames = 0
	scene = load("res://demo02_3d.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene._load_level(5)
	scene.switch_tag(2)
	var launched := false
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 20000:
		frames += 1
		if not launched and scene.ball.linear_velocity.y > 9.0:
			launched = true
			scene.switch_tag(0)   # 起飞即切羽毛，无输入
		if frames % 20 == 0 and launched:
			_log("F t%d pos=(%.2f,%.2f) v=(%.2f,%.2f)" % [frames, scene.ball.position.x, scene.ball.position.y, scene.ball.linear_velocity.x, scene.ball.linear_velocity.y])
		if scene.goal_reached:
			break
		await physics_frame
	_log("F END goal=%s" % str(scene.goal_reached))
	logf.flush()
	quit(0)
