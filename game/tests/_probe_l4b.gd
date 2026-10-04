extends SceneTree
## 探针：L4 皮球+W 弹跳路线，逐帧细拍 + 碰撞监听，定位 vy 截停元凶

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
	logf = FileAccess.open("user://probe_l4b_log.txt", FileAccess.WRITE)
	await process_frame
	scene = load("res://demo02_3d.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene._load_level(3)
	scene.switch_tag(2)
	scene.ball.body_entered.connect(_on_hit)
	var t0 := Time.get_ticks_msec()
	while not scene.goal_reached and Time.get_ticks_msec() - t0 < 15000:
		frames += 1
		if frames % 30 == 0:
			_log("t%d pos=(%.2f,%.2f) v=(%.2f,%.2f)" % [frames, scene.ball.position.x, scene.ball.position.y, scene.ball.linear_velocity.x, scene.ball.linear_velocity.y])
		await physics_frame
	_log("DONE goal=%s" % str(scene.goal_reached))
	logf.flush()
	quit(0)

func _on_hit(other: Node) -> void:
	_log("HIT %s at t%d pos=(%.2f,%.2f) v=(%.2f,%.2f)" % [other.name, frames, scene.ball.position.x, scene.ball.position.y, scene.ball.linear_velocity.x, scene.ball.linear_velocity.y])
