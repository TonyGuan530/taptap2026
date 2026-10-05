extends SceneTree
## L6 探针E：球直接放到浮板上方垂降，隔离验证浮板点火

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
	logf = FileAccess.open("user://probe_l6e_log.txt", FileAccess.WRITE)
	await process_frame
	scene = load("res://demo02_3d.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene._load_level(5)
	for c in scene.get_children():
		if c is Area3D:
			var box2: BoxShape3D = (c.get_child(0) as CollisionShape3D).shape
			_log("AREA " + c.name + " pos=" + str(c.position) + " size=" + str(box2.size) + " monitoring=" + str(c.monitoring) + " mask=" + str(c.collision_mask))
	await physics_frame
	scene.ball.global_position = Vector3(5, 7.5, 0)
	scene.ball.linear_velocity = Vector3.ZERO
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 8000:
		frames += 1
		if frames % 15 == 0:
			_log("t%d pos=(%.2f,%.2f) v=(%.2f,%.2f) in_spring=%s ready=%s" % [frames, scene.ball.position.x, scene.ball.position.y, scene.ball.linear_velocity.x, scene.ball.linear_velocity.y, str(scene.in_spring), str(scene.spring_ready)])
		await physics_frame
	_log("END")
	logf.flush()
	quit(0)
