extends SceneTree
## L6 探针D：弹簧实况 dump + 羽毛两段转向全链路（W→x3.5 松→垂降上板→点火→W→基座）

var scene = null
var logf: FileAccess
var frames := 0
var launched := false
var released := false
var reflung := false

func _log(line: String) -> void:
	print(line)
	if logf:
		logf.store_string(line + "\n")
		logf.flush()

func _init() -> void:
	_run()

func _run() -> void:
	logf = FileAccess.open("user://probe_l6d_log.txt", FileAccess.WRITE)
	await process_frame
	scene = load("res://demo02_3d.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene._load_level(5)
	_log("STATE level_idx=" + str(scene.level_idx) + " LEVELS.size=" + str(scene.LEVELS.size()) + " L6name=" + str(scene.LEVELS[5].name))
	for c in scene.get_children():
		if c is Area3D:
			var box2: BoxShape3D = (c.get_child(0) as CollisionShape3D).shape
			_log("AREA " + c.name + " pos=" + str(c.position) + " size=" + str(box2.size))
		else:
			_log("CHILD " + c.name + " [" + c.get_class() + "]")
	for c in scene.get_children():
		if c is Area3D and c.name == "Spring":
			var box: BoxShape3D = (c.get_child(0) as CollisionShape3D).shape
			_log("SPRING DUMP pos=" + str(c.position) + " size=" + str(box.size))
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 25000 and not scene.goal_reached:
		frames += 1
		if not launched and scene.ball != null and scene.ball.linear_velocity.y > 9.0:
			launched = true
			scene.switch_tag(0)
			scene.yaw = -PI / 2
			Input.action_press("p_fwd")
		if launched and not released and scene.ball.position.x >= 3.5:
			released = true
			Input.action_release("p_fwd")
			_log("RELEASE at x=3.5 t%d" % frames)
		if released and not reflung and scene.ball.linear_velocity.y >= 7.5 and scene.ball.position.y > 5.5:
			reflung = true
			Input.action_press("p_fwd")
			_log("REFLING t%d pos=%s" % [frames, str(scene.ball.position)])
		if frames % 15 == 0 and launched:
			_log("t%d pos=(%.2f,%.2f) v=(%.2f,%.2f) in_spring=%s ready=%s" % [frames, scene.ball.position.x, scene.ball.position.y, scene.ball.linear_velocity.x, scene.ball.linear_velocity.y, str(scene.in_spring), str(scene.spring_ready)])
		await physics_frame
	_log("END goal=%s reflung=%s" % [str(scene.goal_reached), str(reflung)])
	logf.flush()
	quit(0)
