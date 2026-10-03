extends SceneTree
## 探针：L3 羽毛开局，每 30 物理帧记录球状态 → user://p3log.txt

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
	f = FileAccess.open("user://p3log.txt", FileAccess.WRITE)
	await process_frame
	scene = load("res://demo02_physics.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene._load_level(2)
	scene._on_tag(0)
	while tick < 60 * 20:
		await physics_frame
		tick += 1
		if tick % 30 == 0 and scene.ball != null:
			var b = scene.ball
			_log("t=%d pos=(%d,%d) vel=(%d,%d) spring_ready=%s" % [tick, b.position.x, b.position.y, b.linear_velocity.x, b.linear_velocity.y, str(scene.spring_ready)])
		if scene.goal_reached:
			_log("GOAL at t=" + str(tick))
			break
	_log("PROBE DONE")
	f.flush()
	quit()
