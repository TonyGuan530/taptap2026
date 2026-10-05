extends SceneTree
## L6 探针F：in_spring 翻转对照 —— L5 弹跳链 vs L6 直飞（都不切词条）

var scene = null
var logf: FileAccess
var frames := 0
var phase := 0

func _log(line: String) -> void:
	print(line)
	if logf:
		logf.store_string(line + "\n")
		logf.flush()

func _init() -> void:
	_run()

func _run() -> void:
	logf = FileAccess.open("user://probe_l6f_log.txt", FileAccess.WRITE)
	await process_frame
	# 阶段1：L5（index4）皮球零输入，看 in_spring 翻转
	scene = load("res://demo02_3d.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene._load_level(4)
	scene.switch_tag(2)
	var t0 := Time.get_ticks_msec()
	var last := ""
	while Time.get_ticks_msec() - t0 < 6000 and not scene.goal_reached:
		frames += 1
		var st := str(scene.in_spring) + "/" + str(scene.spring_ready)
		if st != last:
			_log("L5 t%d state=%s y=%.2f" % [frames, st, scene.ball.position.y])
			last = st
		await physics_frame
	_log("L5 END goal=%s" % str(scene.goal_reached))
	scene.queue_free()
	await physics_frame
	# 阶段2：L6（index5）皮球不切词条，按住 W 直飞，看 in_spring 翻转
	frames = 0
	last = ""
	scene = load("res://demo02_3d.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene._load_level(5)
	scene.switch_tag(2)
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 8000 and not scene.goal_reached:
		frames += 1
		if frames == 5:
			scene.yaw = -PI / 2
			Input.action_press("p_fwd")
		var st := str(scene.in_spring) + "/" + str(scene.spring_ready)
		if st != last:
			_log("L6 t%d state=%s pos=(%.2f,%.2f)" % [frames, st, scene.ball.position.x, scene.ball.position.y])
			last = st
		await physics_frame
	Input.action_release("p_fwd")
	_log("L6 END goal=%s" % str(scene.goal_reached))
	logf.flush()
	quit(0)
