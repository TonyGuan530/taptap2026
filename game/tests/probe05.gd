extends SceneTree
## 探针：L5 皮球零输入弹跳链轨迹 → user://p5log.txt

var f: FileAccess
var tick := 0
var scene = null

func _log(s: String) -> void:
	if f:
		f.store_string(s + "\n")
		f.flush()

func _init() -> void:
	_run()

func _run() -> void:
	f = FileAccess.open("user://p5log.txt", FileAccess.WRITE)
	await process_frame
	scene = load("res://demo02_physics.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene._load_level(4)
	scene._on_tag(2)
	while tick < 60 * 25 and not scene.goal_reached:
		await physics_frame
		tick += 1
		if scene.ball == null:
			continue
		if tick % 30 == 0:
			var b = scene.ball
			_log("t=%d pos=(%d,%d) vel=(%d,%d) goal=%s" % [tick, b.position.x, b.position.y, b.linear_velocity.x, b.linear_velocity.y, str(scene.goal_reached)])
		if scene.goal_reached:
			_log("GOAL at t=" + str(tick))
			break
	if scene.goal_reached:
		_log("GOAL t=" + str(tick))
	else:
		_log("NO GOAL in 25s engine")
	_log("PROBE DONE")
	f.flush()
	quit()
