extends SceneTree
## L1 探针：spring_areas 内容 + overlaps_body 逐帧状态

var scene = null
var frames := 0

func _log(line: String) -> void:
	print(line)

func _init() -> void:
	_run()

func _run() -> void:
	await process_frame
	scene = load("res://demo02_3d.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene._load_level(0)
	scene.switch_tag(2)
	scene.ball.body_entered.connect(func(b): print("BALLHIT " + b.name + " class=" + b.get_class()))
	scene.yaw = -PI / 2
	Input.action_press("p_fwd")
	_log("areas=" + str(scene.spring_areas.size()))
	for a in scene.spring_areas:
		_log("AREA pos=" + str(a.position) + " imp=" + str(a.get_meta("imp")))
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000:
		frames += 1
		if frames <= 40 or frames % 10 == 0:
			var ov := []
			for a in scene.spring_areas:
				ov.append(a.overlaps_body(scene.ball))
			_log("t%d pos=(%.2f,%.2f) v=(%.2f,%.2f) ov=%s in_spring=%s ready=%s" % [frames, scene.ball.position.x, scene.ball.position.y, scene.ball.linear_velocity.x, scene.ball.linear_velocity.y, str(ov), str(scene.in_spring), str(scene.spring_ready)])
		await physics_frame
	quit(0)
